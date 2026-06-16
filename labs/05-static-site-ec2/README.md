# Lab 05: Static Site on EC2

Terraform tracer bullet for a single EC2-hosted Docker service runtime path.

The lab deploys the shared CIDR Calculator static-site container to Amazon EC2. The shared app under `../../apps/cidr-calculator/` owns the React/Vite SPA, package metadata, Dockerfile, and Nginx runtime config. This lab owns only the EC2 runtime infrastructure, ECR repository boundary, and Terraform stage that pulls an explicit image tag at boot.

## Local SPA development

Do application development from the shared app boundary:

```sh
cd ../../apps/cidr-calculator
mise install
pnpm install
pnpm dev           # starts Vite dev server with hot reload
```

The dev server runs on `http://localhost:5173` by default. Enter an IPv4 CIDR like `192.168.1.0/24` to see derived subnet properties (network address, broadcast, mask, host range, host count, binary representation).

### Production build

```sh
cd ../../apps/cidr-calculator
pnpm build         # outputs static assets to apps/cidr-calculator/dist/
pnpm preview       # serves the production build locally for review
```

The build produces static HTML, JS, and CSS — no Node server needed at runtime.

### Unit tests

```sh
cd ../../apps/cidr-calculator
pnpm test          # runs vitest against the CIDR calculation module
```

## Docker build and local smoke test

Build the Docker image from the shared app build context:

```sh
cd ../../apps/cidr-calculator
docker build -t cidr-calculator:v1 .
```

Run the container locally and verify it serves the SPA:

```sh
docker run --rm -d --name cidr-calculator -p 8090:80 cidr-calculator:v1
```

Smoke test:

```sh
curl -fsS http://localhost:8090 | grep -F "CIDR Calculator"
```

Open `http://localhost:8090` in a browser to confirm the CIDR calculator loads. Stop the local smoke-test container when finished:

```sh
docker stop cidr-calculator
```

The Docker image uses a multi-stage build: Node builds the SPA, then Nginx serves the static output on port 80. The shared Nginx config lives at `../../apps/cidr-calculator/nginx/default.conf` and handles SPA routing via `try_files` plus cache headers on static assets.

### Package scripts shortcut

The shared app `package.json` also provides:

```sh
cd ../../apps/cidr-calculator
pnpm docker:build   # docker build -t cidr-calc .
pnpm docker:run     # docker run --rm -p 8090:80 cidr-calc
pnpm docker:stop    # stops the cidr-calc container
```

## Infrastructure

- Reusable module: `infra/modules/ec2-docker-runtime`
- Stage root: `infra/stage`

The stage root expects a bootstrapped ECR repository and provisions:

- one public EC2 instance in the default VPC/subnets
- an IAM instance profile for SSM Session Manager and ECR image pulls
- a security group with public HTTP ingress on port 80, no SSH ingress, and outbound access
- outputs for image push commands, HTTP access, and SSM inspection

### Backend and variables pattern

This lab uses the `backend.hcl` pattern for backend settings and `.auto.tfvars` for normal Terraform input variables.

Backend config is loaded by `terraform init`, so it cannot come from `.auto.tfvars`.

```sh
cd infra/stage
cp backend.hcl.example backend.hcl
cp stage.auto.tfvars.example stage.auto.tfvars
terraform init -backend-config=backend.hcl
```

The bootstrap root uses the same local-copy pattern when you need to initialise durable prerequisites locally:

```sh
cd infra/bootstrap
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
```

For local syntax validation without remote state:

```sh
cd infra/stage
terraform init -backend=false
terraform validate
```

### Local validation and optional plan

The normal provisioning path is **Approved Deploy** through GitHub Actions, not local `terraform apply`. Use local Terraform commands to validate the Runtime Stage before opening a PR or requesting an approved deploy:

```sh
cd infra/stage
terraform init -backend=false
terraform fmt -recursive -check ../..
terraform validate
terraform test
```

If you have configured `backend.hcl` and `stage.auto.tfvars` locally, you can also run a plan-only preview without changing live infrastructure:

```sh
terraform init -backend-config=backend.hcl
terraform plan
```

Inspect useful commands/URLs after an approved deploy has applied Runtime Stage resources:

```sh
terraform output
```

## CI/CD workflow

This lab has GitHub Actions support for PR checks, manual approved deploys, and manual approved destroys. Bootstrap resources live outside the disposable runtime:

- shared OIDC provider: `infra/bootstrap/aws/`
- lab bootstrap: `infra/bootstrap/` (ECR plus GitHub OIDC roles)
- runtime: `infra/stage/` (EC2 host only)

Create GitHub Environment `lab-05-stage` before using deploy/destroy, and configure its required reviewers in the GitHub repository settings. The PR-check CI workflow runs app lint/test/build, a Docker local smoke test from `apps/cidr-calculator`, Terraform validation, `terraform test`, and a Terraform plan; it does not push images to ECR. The deploy workflow reruns the checks, pushes or reuses this lab's ECR image as `sha-${GITHUB_SHA}`, then applies only Runtime Stage resources in `infra/stage` with that image tag after environment approval. Dispatch `aws-runtime-deploy` from `main`, choose `05-static-site-ec2`, and approve the environment gate. Dispatch `aws-runtime-destroy` to destroy only the EC2 runtime. Destroy removes only Runtime Stage resources; Bootstrap resources survive, including the ECR repository and image history, GitHub OIDC cloud identities/roles, permissions boundaries, and Terraform state foundations.

## Deploy a pushed image tag

Build and push the image separately; Terraform only consumes the explicit tag.
The configured `image_tag` is rendered into EC2 user-data, so changing it replaces
the instance and reruns bootstrap deterministically.

### Step 1: get the ECR repository URL from Terraform

```sh
cd infra/stage
ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
ECR_REGISTRY=$(echo "$ECR_REPOSITORY_URL" | cut -d/ -f1)
```

### Step 2: authenticate Docker to ECR

```sh
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
```

This uses your local AWS credentials (SSO profile, IAM Identity Center, or whatever is in your credential chain) to obtain a short-lived ECR registry password. Docker stores it for the registry host.

### Step 3: build the shared app image, tag it for Lab 05 ECR, and push

From the shared app root:

```sh
cd /path/to/apps/cidr-calculator
docker build -t cidr-calculator:v1 .
docker tag cidr-calculator:v1 "$ECR_REPOSITORY_URL:v1"
docker push "$ECR_REPOSITORY_URL:v1"
```

You can also get ready-to-run commands from Terraform. Run them from `labs/05-static-site-ec2/infra/stage`; the generated Docker build command points back to the shared app context:

```sh
cd /path/to/labs/05-static-site-ec2/infra/stage
terraform output docker_build_tag_push_commands
```

### Step 4: request Approved Deploy with the explicit image tag

The normal deploy path is the `aws-runtime-deploy` GitHub Actions workflow. Dispatch `aws-runtime-deploy` from `main`, choose `05-static-site-ec2`, and approve the `lab-05-stage` GitHub Environment gate. The workflow passes the immutable `sha-${GITHUB_SHA}` image tag into Terraform and applies only the Runtime Stage.

For plan-only local inspection, set `image_tag` in `infra/stage/stage.auto.tfvars` and run `terraform plan`; do not use local apply as the learner provisioning path.

Terraform renders the image tag into the EC2 user-data template. The instance boots, installs Docker, authenticates to ECR through its instance role, pulls the exact tagged image, and runs it on port 80.

### Step 5: verify the deployed service

```sh
cd infra/stage
SERVICE_URL=$(terraform output -raw service_url)
curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL"
# expected: 200
```

Open the service URL in a browser to confirm the CIDR calculator is live.

### CI-built image tag handoff

If a CI/CD system such as GitHub Actions builds and pushes the image, Terraform
will not automatically know the Git commit SHA used as the image tag unless that
same value is passed into Terraform.

For example, if GitHub Actions pushes:

```text
cidr-calculator:sha-${GITHUB_SHA}
```

then a Terraform run outside that pipeline must receive the same tag explicitly:

```sh
terraform plan -var="image_tag=sha-<github-sha>"
```

Terraform should not try to derive the tag by running `git rev-parse HEAD`: the
local checkout may not match the commit that CI built, and the resulting plan
would depend on the machine running Terraform rather than the deployed artifact.

If CI builds images but does not run Terraform, use one of these handoff patterns:

- copy the CI-produced SHA/tag and pass it manually with `-var="image_tag=..."`
- have CI publish the built tag as an artifact or release note
- have CI write the approved image tag to a small deployment record such as SSM
  Parameter Store, then make Terraform read that value explicitly

Avoid relying only on a mutable tag such as `latest` or `stage`: Terraform will
not see the image contents change when the tag name stays the same, so the EC2
instance will not be replaced unless you also change `image_tag` or force a
replacement.

## SSM Session Manager access (no SSH)

The EC2 instance is accessible through **AWS Systems Manager Session Manager** only. There is no SSH key pair, no port 22 ingress, and no SSH daemon exposed to the internet. This is intentional — Session Manager provides secure shell access through the AWS control plane without managing keys or opening inbound network paths.

Connect to the instance:

```sh
cd infra/stage
terraform output ssm_start_session_command
# run the printed command
```

This opens an interactive shell on the EC2 instance through the SSM agent.

### Troubleshooting bootstrap

On the instance, check cloud-init and the service logs:

```sh
sudo tail -n 200 /var/log/cidr-calculator-user-data.log
sudo journalctl -u cidr-calculator.service --no-pager
```

The user-data script logs to both `/var/log/cidr-calculator-user-data.log` and journald. The `cidr-calculator` systemd unit depends on Docker and runs the container pull-and-run script at boot.

Common failure points:

- Docker install or service start failed → check `journalctl -u docker.service`
- ECR authentication failed → check the instance role has the ECR pull policy attached
- Image pull failed → verify the tag exists in ECR: `aws ecr describe-images --repository-name <name> --region ap-northeast-1`
- Container not listening on port 80 → `docker logs cidr-calculator`

## How EC2 gets source-derived artifacts

This lab uses **ECR container images** as the artifact delivery mechanism, but that is not the only option. Understanding the alternatives helps explain why this choice fits the lab.

### Options for getting built artifacts onto EC2

| Method | How it works | Trade-offs |
|--------|-------------|------------|
| **ECR container images** | Build a Docker image locally or in CI, push to ECR. EC2 pulls and runs the image at boot via user-data. | Clean separation of build and infra. Immutable artifacts with explicit tags. Requires Docker on EC2. Requires ECR repository and IAM pull permissions. Chosen for this lab. |
| **AMI baking (Packer)** | Build a custom AMI with the application baked in. Terraform launches EC2 from that AMI. | Fast boot (no install step). Strong immutability. But AMI management adds complexity: regional copying, cleanup, AMI ID tracking across Terraform configs. |
| **S3 artifact sync** | CI uploads a build archive (tar, zip) to S3. EC2 user-data downloads and extracts it at boot. | Works for any artifact type. Simple. But requires the instance to know the S3 path and version, and you manage the extraction/startup logic yourself. |
| **Git pull in cloud-init** | EC2 clones the repo and runs a build step during boot. | Simple for prototypes. But couples the instance to repo access, requires build tools on the instance, and boot time depends on git clone + build. Not deterministic if the branch moves. |
| **AWS CodeDeploy** | Deploy agent on EC2 pulls revision bundles from S3 or GitHub. Supports blue/green and rolling deploys. | Production-grade deployment automation. But heavy for a single-instance lab. Requires CodeDeploy agent, appspec, and deployment group configuration. |
| **SSM State Manager / Run Command** | AWS SSM pushes commands or state configurations to managed instances. | Good for config management and ad-hoc commands. Can trigger container restarts or updates. But not a primary artifact delivery mechanism for this use case. |
| **Terraform provisioners (local-exec, remote-exec)** | Terraform runs shell commands as part of apply. Can build images, copy files, or run remote commands. | Couples build steps to Terraform apply. Breaks determinism and plan preview. Makes Terraform depend on local tooling. Explicitly avoided in this lab. |

### Why ECR container images for this lab

1. **Separation of concerns** — Terraform owns infrastructure. Docker owns the artifact. Neither leaks into the other.
2. **Immutable deployments** — Each image tag points to a specific built artifact. Changing the tag triggers EC2 replacement through `user_data_replace_on_change` and `replace_triggered_by`.
3. **No build tools on the instance** — The EC2 instance only needs Docker. No Node, no pnpm, no git on the runtime host.
4. **Auth follows IAM** — The EC2 instance role grants ECR pull access. No embedded credentials or secrets.
5. **Scalable path** — The same ECR-based workflow extends to ECS, EKS, or future CI/CD pipelines without rethinking the artifact layer.

## Known trade-offs

This lab is a tracer bullet, not a production deployment. The following limitations are intentional for this iteration.

### Default VPC

The lab uses the AWS account's default VPC and subnets. This avoids networking complexity but means the instance lands in a public subnet with no controlled egress through a NAT gateway or private subnet topology. A production deployment would use a dedicated VPC with private subnets, NAT, and VPC endpoints for ECR and SSM.

### Single instance downtime

Changing `image_tag` triggers EC2 replacement. The old instance terminates and a new one boots. During that window the service is unavailable. This is acceptable for a learning lab. A production setup would use an ALB with a target group and blue/green rotation, an Auto Scaling Group, or a container orchestrator like ECS.

### No HTTPS

The service is served over plain HTTP on port 80. There is no TLS termination, no ACM certificate, no Route 53 domain, and no CloudFront distribution. In a real deployment you would front the instance or ALB with HTTPS. For this lab the HTTP-only path keeps the focus on Docker, ECR, and Terraform.

### No ALB or Auto Scaling Group

A single EC2 instance is the simplest runnable shape. There is no load balancer health checking the container, no auto-scaling to handle traffic changes, and no multi-AZ redundancy. These are natural next steps for a more production-shaped iteration.

## Teardown

Use the `aws-runtime-destroy` GitHub Actions workflow for approved runtime teardown. Dispatch `aws-runtime-destroy`, choose `05-static-site-ec2`, and approve the `lab-05-stage` GitHub Environment gate.

Destroy removes only Runtime Stage resources such as the EC2 instance, instance profile, and security group. Bootstrap resources survive runtime destroy, including the ECR repository and image history, GitHub OIDC cloud identities/roles, permissions boundaries, and Terraform state foundations.

## Further reading

The lab includes reflective blog posts that go deeper into specific topics:

- `blog-auth-ecr-docker-ec2-terraform.md` — how the authentication chain works across SSO, STS, ECR, Docker, and EC2 instance roles
- `blog-remote-backend-management.md` — why `backend.hcl` and `.auto.tfvars` belong to different Terraform lifecycle phases
