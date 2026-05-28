# How ECR, Docker, EC2, Terraform, and My CLI Actually Authenticate

While working on the EC2 static-site lab, I hit a point where the commands looked simple but the trust chain felt blurry:

```sh
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin <registry>

docker push <repository-url>:<tag>
```

The command is short, but it crosses several systems:

- my local shell
- `aws-sso-cli`
- AWS IAM Identity Center
- AWS STS
- AWS CLI
- Amazon ECR
- Docker
- Terraform
- EC2 instance profiles
- EC2 user-data

At first I was treating this as “log in to AWS, then Docker can push.” That is mostly true, but it hides the important part: **Docker never logs in to AWS IAM directly**. Docker logs in to a registry using a temporary registry password that the AWS CLI asks ECR to generate.

That distinction made the whole system easier to reason about.

## What I wanted to understand

I wanted clear answers to these questions:

1. What do I need before I can run `aws ecr` commands?
2. How does my third-party `aws-sso-cli` login connect to normal AWS CLI commands?
3. How does Docker authenticate to ECR if Docker does not know about IAM Identity Center?
4. What changes when the same image is pulled from EC2 user-data instead of pushed from my laptop?
5. What role does Terraform play, and what does Terraform **not** do?

The mental model I ended up with is:

> My CLI authenticates to AWS.  
> AWS CLI asks ECR for a Docker-compatible password.  
> Docker authenticates to the ECR registry using that password.  
> EC2 does the same thing, but with its instance role instead of my SSO session.  
> Terraform creates the infrastructure and IAM wiring, but it does not transfer my local login to EC2.

## The actors

There are a few separate identities and tools involved.

### My human identity

I log in through AWS IAM Identity Center using `aws-sso-cli`.

In my local terminal, that usually means one of these patterns:

```sh
aws-sso-profile <profile-name>
```

or:

```sh
aws-sso exec -- aws sts get-caller-identity
```

or, after configuring profiles:

```sh
AWS_PROFILE=<profile-name> aws sts get-caller-identity
```

The important part is that after this step, AWS CLI commands can obtain temporary AWS credentials for the selected account and role.

Those credentials are not permanent IAM access keys. They are temporary credentials backed by IAM Identity Center and STS.

### AWS CLI

The AWS CLI uses whatever credentials are available through the normal AWS credential chain:

- environment variables
- `AWS_PROFILE`
- `credential_process`
- cached SSO/STS credentials
- config in `~/.aws/config`

With `aws-sso-cli`, a profile can be configured so the AWS CLI calls `aws-sso process` through `credential_process`. From the AWS CLI's point of view, it just receives temporary credentials it can use to call AWS APIs.

A quick sanity check is:

```sh
aws sts get-caller-identity
```

or with an explicit profile:

```sh
AWS_PROFILE=<profile-name> aws sts get-caller-identity
```

If this command fails, `aws ecr` will fail too. ECR authentication starts with normal AWS API authentication.

### Terraform

Terraform is another AWS API client.

When I run:

```sh
cd infra/stage
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Terraform's AWS provider uses the same kind of credential chain as the AWS CLI. If my shell has a valid SSO-backed profile, Terraform can use it to create infrastructure.

In this lab, Terraform creates things like:

- the ECR repository
- the EC2 instance
- the EC2 IAM role and instance profile
- the policy allowing the EC2 role to pull from ECR
- the security group
- outputs containing the ECR repository URL

But Terraform does **not** build the Docker image. It also does **not** push the image to ECR. That is intentionally separate.

Terraform prepares the destination. Docker and AWS CLI move the image.

### Docker

Docker understands container registries. It does not understand IAM Identity Center, STS, IAM roles, or Terraform.

When I run:

```sh
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/stage-static-site-ec2-cidr-calculator:v1
```

Docker needs registry credentials for:

```text
123456789012.dkr.ecr.ap-northeast-1.amazonaws.com
```

Those credentials are installed by `docker login`.

For ECR, the username is always:

```text
AWS
```

The password comes from:

```sh
aws ecr get-login-password
```

That password is temporary. Docker stores it like any other registry login, often through Docker Desktop's credential store or `~/.docker/config.json`, depending on the machine.

## The local push flow

The local push flow has two authentication steps:

1. My terminal authenticates to AWS.
2. Docker authenticates to ECR using a token requested by AWS CLI.

The flow looks like this:

```text
Human
  -> aws-sso-cli login / profile selection
  -> temporary AWS credentials available to shell
  -> aws ecr get-login-password
  -> ECR returns Docker registry password
  -> docker login stores registry auth
  -> docker push uploads image layers to ECR
```

A practical command sequence from this lab looks like this.

First, go to the Terraform stage root and make sure the infrastructure exists:

```sh
cd infra/stage
terraform apply
```

Then get the repository URL Terraform created:

```sh
ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
```

For this lab, it should look something like:

```text
123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/stage-static-site-ec2-cidr-calculator
```

The part before the slash is the registry host:

```sh
ECR_REGISTRY=$(echo "$ECR_REPOSITORY_URL" | cut -d/ -f1)
```

That gives:

```text
123456789012.dkr.ecr.ap-northeast-1.amazonaws.com
```

Then choose an explicit image tag:

```sh
IMAGE_TAG=v1
```

Issue #5 specifically wants an explicit image tag because the EC2 instance should run a known image version, not some vague moving target.

From the lab root, build the image:

```sh
cd /Users/noid/hub/dev/portfolio/devops/labs/05-static-site-ec2

docker build -t cidr-calculator:$IMAGE_TAG .
```

Authenticate Docker to the ECR registry:

```sh
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
```

Tag the local image with the full ECR repository URL:

```sh
docker tag cidr-calculator:$IMAGE_TAG "$ECR_REPOSITORY_URL:$IMAGE_TAG"
```

Push it:

```sh
docker push "$ECR_REPOSITORY_URL:$IMAGE_TAG"
```

Verify that ECR can see the image:

```sh
aws ecr describe-images \
  --region ap-northeast-1 \
  --repository-name "$(basename "$ECR_REPOSITORY_URL")"
```

The placeholders are:

| Placeholder | Meaning | Example |
|---|---|---|
| `<profile-name>` | AWS SSO profile/role selected by `aws-sso-cli` | `dev-admin` |
| `<registry>` | ECR registry host | `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com` |
| `<repository-url>` | Full ECR repository URL from Terraform | `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/stage-static-site-ec2-cidr-calculator` |
| `<tag>` | Explicit image version | `v1`, `2026-05-28-001`, or a git SHA |

## What `aws ecr get-login-password` actually does

This command is the bridge between AWS IAM authentication and Docker registry authentication:

```sh
aws ecr get-login-password --region ap-northeast-1
```

To run it successfully, the AWS CLI needs valid AWS credentials. In my setup, those credentials come from `aws-sso-cli` and IAM Identity Center.

The AWS CLI then calls ECR's authorization API. ECR returns a short-lived password that Docker can use for the registry endpoint.

So this command:

```sh
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
```

means:

```text
AWS CLI: I am authenticated as this IAM role. Please give me an ECR registry password.
ECR: Here is a temporary Docker-compatible password.
Docker: I will store this password for this registry host.
```

After that, `docker push` does not call IAM Identity Center. It talks to the Docker Registry API exposed by ECR and uses the registry credentials saved by `docker login`.

## Required permissions for local push

The SSO-selected role needs permission to push images to ECR.

At minimum, the identity needs actions such as:

```text
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

For a lab, an AWS-managed policy like `AmazonEC2ContainerRegistryPowerUser` is usually enough for the local push side.

This is separate from the EC2 instance role. My local role pushes. The EC2 role pulls.

## The EC2 pull flow

EC2 has a different identity.

The EC2 instance does not use my local `aws-sso-cli` session. It cannot see my terminal, my browser login, my `AWS_PROFILE`, or my cached SSO credentials.

Instead, Terraform attaches an IAM instance profile to the EC2 instance.

In this lab, the module creates an EC2 role with permissions for:

- SSM Session Manager
- ECR image pulls

The EC2 instance obtains temporary credentials through the Instance Metadata Service. Those credentials belong to the instance role.

The flow on EC2 looks like this:

```text
EC2 instance
  -> instance profile attached by Terraform
  -> IMDS provides temporary role credentials
  -> aws ecr get-login-password
  -> ECR returns Docker registry password
  -> docker login stores registry auth on EC2
  -> docker pull downloads image
  -> docker run starts container on port 80
```

This is the same ECR-to-Docker bridge as the local push flow, but the AWS identity is different.

Local push:

```text
aws-sso-cli / IAM Identity Center role -> AWS CLI -> ECR token -> Docker push
```

EC2 pull:

```text
EC2 instance role -> AWS CLI on instance -> ECR token -> Docker pull
```

That separation is important. If my laptop can push but EC2 cannot pull, the problem is probably not my SSO login. It is probably the EC2 instance role, ECR policy, region, repository URL, image tag, or user-data script.

## Terraform's role in the auth chain

Terraform is responsible for the long-lived wiring:

```text
Terraform
  -> creates ECR repository
  -> creates EC2 IAM role
  -> attaches ECR pull policy to EC2 role
  -> creates EC2 instance with that instance profile
  -> renders user-data with repository URL, region, and tag
```

Terraform is not responsible for these things:

```text
Terraform does not log Docker in from my laptop.
Terraform does not build the image.
Terraform does not push the image.
Terraform does not pass my SSO session to EC2.
Terraform should not use local-exec as a hidden image deployment pipeline for this lab.
```

That last point matters for issue #5. The goal is not to make Terraform secretly run Docker commands. The goal is to make Terraform accept an explicit image tag and make EC2 boot into that exact image.

The image publishing step stays outside Terraform:

```text
docker build -> docker tag -> docker push
```

The runtime deployment step belongs to Terraform and EC2 user-data:

```text
terraform apply -> EC2 replaced if image tag changes -> user-data pulls exact tag -> container runs
```

## Why changing the image tag should replace EC2

User-data normally runs at first boot. If I change a Terraform variable from:

```hcl
image_tag = "v1"
```

to:

```hcl
image_tag = "v2"
```

I do not want Terraform to leave the old container running silently.

This lab uses the EC2 instance as a simple tracer bullet runtime. The deterministic behavior should be:

```text
change image tag
  -> user-data changes
  -> EC2 instance is replaced
  -> new instance boots
  -> new user-data runs
  -> Docker pulls the new exact image tag
```

That is why the Terraform EC2 resource uses:

```hcl
user_data_replace_on_change = true
```

The image tag becomes part of the instance bootstrap contract.

## Debugging the chain

When something fails, it helps to identify which boundary failed.

### Can my CLI call AWS?

```sh
aws sts get-caller-identity
```

If this fails, fix the SSO/profile setup before touching Docker.

With an explicit profile:

```sh
AWS_PROFILE=<profile-name> aws sts get-caller-identity
```

### Did Terraform create the ECR repository?

```sh
cd infra/stage
terraform output -raw ecr_repository_url
```

If this fails, Terraform state or apply has not reached the point where ECR exists.

### Can AWS CLI get an ECR password?

```sh
aws ecr get-login-password --region ap-northeast-1 >/dev/null
```

If this fails, the selected AWS identity probably lacks ECR auth permission or is using the wrong region/account.

### Is Docker logged in to the right registry?

```sh
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
```

Make sure `$ECR_REGISTRY` is only the host, not the full repository path.

Correct:

```text
123456789012.dkr.ecr.ap-northeast-1.amazonaws.com
```

Incorrect:

```text
123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/stage-static-site-ec2-cidr-calculator
```

### Did I push the tag EC2 is trying to pull?

```sh
aws ecr describe-images \
  --region ap-northeast-1 \
  --repository-name "$(basename "$ECR_REPOSITORY_URL")" \
  --query 'imageDetails[].imageTags'
```

If Terraform says `image_tag = "v1"`, then ECR must contain `:v1`.

### Can EC2 assume its own role?

On the instance, the AWS CLI should use the instance profile automatically. Through SSM, I can inspect:

```sh
aws sts get-caller-identity
```

The ARN should be an assumed role for the EC2 instance role, not my local SSO role.

### Did user-data run?

On Amazon Linux, cloud-init logs are usually the first place to look:

```sh
sudo tail -n 200 /var/log/cloud-init-output.log
```

For this lab, readable user-data and logs matter because most deployment failures will happen during boot: Docker install, ECR login, image pull, or container run.

## The final picture

The whole system has two mirrored auth flows.

Local publish path:

```text
Me
  -> IAM Identity Center
  -> aws-sso-cli
  -> AWS CLI temporary credentials
  -> ECR authorization token
  -> Docker registry login
  -> docker push image:tag
```

EC2 runtime path:

```text
EC2 instance
  -> IAM instance profile
  -> IMDS temporary credentials
  -> ECR authorization token
  -> Docker registry login
  -> docker pull image:tag
  -> docker run on port 80
```

Terraform sits beside those flows as the infrastructure author:

```text
Terraform
  -> uses my local AWS credentials to create ECR, EC2, IAM, and user-data
  -> outputs the repository URL
  -> wires the EC2 role so the instance can pull
  -> replaces EC2 when the configured image tag changes
```

The subtle lesson is that there is no single global “AWS login.” There are scoped, temporary credentials at each boundary.

My laptop has one identity. EC2 has another. Docker has registry credentials derived from whichever AWS identity asked ECR for a token. Terraform uses AWS credentials to create the wiring, but it does not become the runtime identity.

Once I separated those responsibilities, the commands became less magical:

```sh
aws ecr get-login-password | docker login
```

is not just boilerplate. It is the handoff between AWS IAM and the Docker Registry protocol.

## Unfinished question

For this lab, user-data is enough because the goal is a small tracer bullet. The next question is where the boundary should move in a more production-shaped system: systemd unit, ECS, SSM State Manager, CodeDeploy, or a real deployment pipeline.

For now, the important part is that I can explain who is authenticated at every step, and that is already a much better place to be than copying ECR commands without knowing what they mean.

## References

- [AWS SSO CLI quickstart](https://synfinatic.github.io/aws-sso-cli/latest/quickstart/#use-aws-sso-on-the-cli-for-aws-api-calls)
