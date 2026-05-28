# Diagnosing a Silent EC2 Failure: Architecture Mismatch Between Docker and the Cloud

Terraform reported success. All resources created. The instance was running. The service URL returned "connection refused."

I had just provisioned a single EC2 instance to host a static site in a Docker container. The pipeline is intentionally simple: Terraform creates the infrastructure (ECR, EC2, IAM, security group), I build and push a Docker image separately, and user-data on the instance pulls that image and runs it. Every piece checked out individually. Nothing worked together.

What I wanted to understand was: **how do you actually find out what went wrong inside a remote instance you can't SSH into, when everything Terraform controls looks healthy?**

What I learned is that the diagnostic path is surprisingly methodical once you know which AWS surfaces to check, and the bug itself was a quiet mismatch between my laptop's CPU architecture and the instance's CPU architecture — the kind of thing Docker abstracts away until it doesn't.

## The symptom

After `terraform apply` completed, I grabbed the service URL:

```sh
curl -sS --connect-timeout 5 -o /dev/null -w "%{http_code}" \
  http://ec2-35-76-27-178.ap-northeast-1.compute.amazonaws.com
```

Result: connection refused on port 80.

The output said the infrastructure was fine. The instance was running. The security group allowed HTTP from `0.0.0.0/0`. ECR had images. But nothing was listening on port 80 inside the instance.

## The mental model for debugging remote instances

Before jumping into tools, it helps to frame the problem as a chain of boundaries, each with its own observable surface:

```text
Terraform state     →  AWS console / CLI
Instance lifecycle  →  EC2 describe-instance-status
Network path        →  Security groups, curl from outside
Service on host     →  Systemd unit status
Container runtime   →  Docker pull and run logs
Image artifact      →  ECR image tags and manifests
```

Each boundary can pass while a deeper one fails. Terraform succeeding only tells you the first boundary is intact.

## Tool 1: Terraform output — what Terraform believes is true

Start with what Terraform knows. The outputs give you the instance ID, public IP, DNS name, security group, and ECR details. These are the coordinates for every other diagnostic step.

```sh
cd infra/stage
terraform output -json
```

This gave me the instance ID (`i-0aca0054bf6cdf6bd`), the public DNS name, the service URL, and the SSM session command. Everything looked correct. The problem was downstream.

**When this is useful:** You need the instance ID for every subsequent AWS CLI call, and you need to verify that Terraform's view of the world matches what you expect — correct region, correct repository, correct tag.

## Tool 2: EC2 instance status — is the instance actually healthy?

Even though Terraform says the instance is running, AWS has its own reachability checks. If the instance failed to bootstrap, the status checks can tell you.

```sh
aws ec2 describe-instance-status \
  --instance-ids i-0aca0054bf6cdf6bd \
  --region ap-northeast-1
```

In my case, both the instance status and system status reported `passed`. The instance was reachable at the hypervisor level. The problem was inside the OS, not in the AWS infrastructure layer.

**When this is useful:** You want to rule out AWS-level failures — impaired hardware, networking issues at the hypervisor, or an instance that's in `stopping`/`stopped` state while Terraform still shows it as created.

## Tool 3: ECR image listing — does the tag exist at all?

The user-data script pulls an image by tag. If the tag doesn't exist in ECR, the pull fails silently (or loudly, depending on where you look).

```sh
aws ecr describe-images \
  --repository-name stage-static-site-ec2-cidr-calculator \
  --region ap-northeast-1
```

This revealed something important: ECR had images tagged `v1` but **no image tagged `latest`**. The Terraform variable `image_tag` was set to `latest`, so the user-data was trying to pull `:latest` — a tag that didn't exist.

This was the first concrete clue. The build/push step had used `v1` as the tag, but the infrastructure was configured to pull `latest`.

**When this is useful:** Any time the deployment depends on a specific image tag. The ECR API is the source of truth for what tags actually exist, independent of what Terraform or your CI pipeline believes was pushed.

## Tool 4: curl — does the network path work at all?

A quick external probe confirms whether the security group and network path are functional:

```sh
curl -sS --connect-timeout 5 --max-time 10 \
  -o /dev/null -w "%{http_code}" \
  http://ec2-35-76-27-178.ap-northeast-1.compute.amazonaws.com
```

Connection refused means the network path is open (we reached the host), but nothing is listening on port 80. If the security group had blocked us, we'd see a timeout instead. The distinction matters: timeout is a network problem, connection refused is a service problem.

**When this is useful:** Quickly separating network-level issues from application-level issues. If you get a timeout, check security groups, NACLs, and routing. If you get connection refused, the network is fine — something inside the host isn't running.

## Tool 5: AWS SSM Run Command — running diagnostics without SSH

This lab doesn't expose SSH. The instance is only accessible through AWS Systems Manager Session Manager. But you don't need an interactive session to run diagnostic commands. SSM Run Command lets you execute shell commands on the instance and retrieve the output.

```sh
aws ssm send-command \
  --instance-ids i-0aca0054bf6cdf6bd \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl status --no-pager cidr-calculator.service"]' \
  --region ap-northeast-1
```

This returns a command ID. After a short wait, retrieve the output:

```sh
aws ssm get-command-invocation \
  --command-id <command-id> \
  --instance-id i-0aca0054bf6cdf6bd \
  --region ap-northeast-1 \
  --output json | jq -r '.StandardOutputContent'
```

This was the tool that actually revealed the error. The systemd unit had failed:

```text
Active: failed (Result: exit-code)
...
Error response from daemon: manifest for .../cidr-calculator:latest not found:
  manifest unknown: Requested image not found
```

The Docker pull had failed because the `latest` tag didn't exist. The service never started.

**When this is useful:** This is your primary window into a remote instance without SSH. You can check systemd units, read log files, inspect Docker containers, test network connectivity — anything you'd do in a shell session, but scripted and retrievable.

## Tool 6: User-data logs — what happened at first boot?

EC2 user-data runs at first boot. For this lab, the user-data template installs Docker, authenticates to ECR, pulls the image, and starts the container. The template also configures logging:

```sh
exec > >(tee -a /var/log/cidr-calculator-user-data.log | logger -t cidr-calculator-user-data -s 2>/dev/console) 2>&1
```

Through SSM Run Command, I read that log:

```sh
aws ssm send-command \
  --instance-ids i-0aca0054bf6cdf6bd \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["tail -40 /var/log/cidr-calculator-user-data.log"]' \
  --region ap-northeast-1
```

This shows the full bootstrap sequence — Docker installation, ECR login, image pull attempt, and the failure. For first-boot issues, this log is often the first place to look.

**When this is useful:** Any time user-data might have failed. The cloud-init output log (`/var/log/cloud-init-output.log`) is another option on Amazon Linux, but this lab's user-data writes to its own log file for clarity.

## The first fix attempt: retagging

The immediate problem was clear — no `latest` tag existed. I retagged the `v1` image as `latest` and pushed it to ECR:

```sh
docker pull <ecr-url>:v1
docker tag <ecr-url>:v1 <ecr-url>:latest
docker push <ecr-url>:latest
```

Then restarted the service through SSM:

```sh
aws ssm send-command \
  --instance-ids i-0aca0054bf6cdf6bd \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl restart cidr-calculator.service"]' \
  --region ap-northeast-1
```

The service failed again. This time with a different error:

```text
no matching manifest for linux/amd64 in the manifest list entries
```

## Tool 7: docker buildx imagetools — inspecting multi-arch manifests

This error message is Docker's way of saying "this image exists but not for your CPU architecture." The EC2 instance is `x86_64` (amd64). The image only contained a `linux/arm64` manifest.

To inspect what architectures an image actually supports:

```sh
docker buildx imagetools inspect \
  549475122024.dkr.ecr.ap-northeast-1.amazonaws.com/stage-static-site-ec2-cidr-calculator:v1
```

Output:

```text
Manifests:
  Name:      ...@sha256:2f66b6add1...
  Platform:  linux/arm64

  Name:      ...@sha256:3076307939...
  Platform:  unknown/unknown
  Annotations:
    vnd.docker.reference.type:    attestation-manifest
```

Only `linux/arm64`. No `linux/amd64`. The image was built on my Apple Silicon Mac, and `docker build` defaulted to the local architecture. When I retagged it as `latest`, I copied only the arm64 manifest. The EC2 instance couldn't run it.

**When this is useful:** Any time you see "no matching manifest" errors, or when building on one architecture for deployment on another. This tool shows exactly what platforms an image supports, including attestation manifests.

## The real fix: building for the target architecture

The Dockerfile itself didn't specify a platform — it used `node:24-alpine` and `nginx:1.27-alpine`, both of which support multi-arch. The problem was that `docker build` on an arm64 host produces an arm64 image unless you tell it otherwise.

The fix was to rebuild with an explicit platform:

```sh
docker buildx build \
  --platform linux/amd64 \
  --tag <ecr-url>:latest \
  --push \
  .
```

This builds the image using QEMU emulation (or a remote builder) for amd64, and pushes it directly to ECR. After the push, the `latest` tag contained a proper `linux/amd64` manifest.

Restarting the service on the instance:

```sh
aws ssm send-command \
  --instance-ids i-0aca0054bf6cdf6bd \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl restart cidr-calculator.service"]' \
  --region ap-northeast-1
```

And verifying:

```sh
curl -sS -o /dev/null -w "%{http_code}" http://ec2-35-76-27-178.ap-northeast-1.compute.amazonaws.com
# 200
```

The service was up.

## The diagnostic path, summarized

Here's the boundary chain again, with the tool that exposes each layer:

| Boundary | What to check | Tool |
|----------|--------------|------|
| Terraform state | Outputs, resource addresses | `terraform output -json` |
| Instance health | Reachability, running state | `aws ec2 describe-instance-status` |
| Artifact existence | Tags, digests in ECR | `aws ecr describe-images` |
| Network path | TCP reachability from outside | `curl -sS` |
| Service on host | Systemd unit status | SSM Run Command → `systemctl status` |
| Bootstrap logs | User-data execution | SSM Run Command → `tail /var/log/...` |
| Container runtime | Docker pull/run errors | SSM Run Command → `docker ps`, `journalctl` |
| Image architecture | Platform manifests | `docker buildx imagetools inspect` |

The pattern is: start from the outside, work inward. Each tool narrows the problem space until the specific failure surfaces.

## What made this confusing

There were two distinct problems stacked on top of each other:

1. **Missing tag.** The image was pushed as `:v1` but the infrastructure expected `:latest`. This is a process mismatch — the build/push step and the Terraform config need to agree on the tag. The README documents this clearly (use an explicit tag, set it in `stage.auto.tfvars`), but if you push with one tag and configure another, nothing tells you until the instance fails to boot.

2. **Architecture mismatch.** Even after fixing the tag, the image only contained an arm64 manifest because it was built on an arm64 host with no explicit `--platform` flag. Docker's default behavior (build for the local architecture) is reasonable for local development, but it silently produces images that won't run on cloud instances unless you're intentional about the target platform.

Neither problem produced an error at the Terraform level. Neither showed up in security group checks or instance status. The errors only appeared inside the instance, in the systemd unit logs, after Docker tried to pull an image that either didn't exist (wrong tag) or couldn't run (wrong architecture).

This is the nature of infrastructure that delegates runtime work to user-data: Terraform can verify that the plumbing exists, but it can't verify that the water flows.

## Unfinished question

For this lab I rebuilt for `linux/amd64` only. A more durable approach would be to build multi-arch images:

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag <ecr-url>:<tag> \
  --push .
```

This produces an image index that Docker can resolve to the correct manifest on any host. The question I haven't fully explored is how this interacts with CI pipelines — specifically, whether CI runners on amd64 would naturally produce amd64 images, or whether the `--platform` flag should always be explicit to prevent this class of bug from recurring when runner architectures change.

The deeper lesson is that "it works on my machine" has an architecture-shaped shadow. Docker makes cross-platform builds look easy — `FROM node:24-alpine` works everywhere — but the output image is still bound to a specific architecture unless you consciously choose otherwise.
