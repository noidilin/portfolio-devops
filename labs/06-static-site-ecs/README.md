# Lab 06: Static Site on ECS Express Mode

Terraform tracer bullet for migrating the Lab 05 EC2 Docker runtime to Amazon ECS Express Mode.

The lab builds the same client-side IPv4 CIDR calculator SPA, packages it as a static Nginx site in Docker, pushes the image to Amazon ECR, and uses Terraform to deploy the container with `aws_ecs_express_gateway_service`.

ECS Express Mode manages the Fargate service, HTTPS endpoint, load balancer, target groups, security groups, deployment flow, auto scaling, and CloudWatch integration.

## Local SPA development

```sh
cd app
pnpm install
pnpm dev
```

Production build and tests:

```sh
cd app
pnpm build
pnpm test
```

## Docker build and local smoke test

Build from the lab root:

```sh
cd /path/to/labs/06-static-site-ecs
docker build -t cidr-calculator:v1 .
```

Run locally:

```sh
docker run --rm -p 8090:80 cidr-calculator:v1
curl -s -o /dev/null -w "%{http_code}" http://localhost:8090
# expected: 200
```

## Infrastructure

- Reusable module: `infra/modules/ecs-express-static-site`
- Stage root: `infra/stage`

The stage root expects a bootstrapped ECR repository and provisions:

- an ECS cluster
- ECS task execution, task, and infrastructure IAM roles with the lab permissions boundary
- a CloudWatch log group
- an ECS Express Gateway service using the ECR image tag you provide
- outputs for image push commands, service inspection, logs, and HTTPS access

## CI/CD workflow

This lab has GitHub Actions support for PR checks, manual approved deploys, and manual approved destroys. Bootstrap resources live outside the disposable runtime:

- shared OIDC provider: `infra/account-bootstrap/github-oidc-provider/`
- lab bootstrap: `infra/bootstrap/` (ECR plus GitHub OIDC roles)
- runtime: `infra/stage/` (ECS Express service only)

Create GitHub Environment `lab-06-stage` with required reviewers before using deploy/destroy. Dispatch `Lab container deploy` from `main`, choose `06-static-site-ecs`, approve the environment gate, and the workflow deploys image tag `sha-${GITHUB_SHA}`. Dispatch `Lab container destroy` to destroy only the ECS runtime; ECR, OIDC, roles, and image history remain.

See [`../../docs/container-cicd-ec2-ecs.md`](../../docs/container-cicd-ec2-ecs.md) for the full runbook.

## Backend and variables pattern

```sh
cd infra/stage
cp backend.hcl.example backend.hcl
cp stage.auto.tfvars.example stage.auto.tfvars
terraform init -backend-config=backend.hcl
```

For local syntax validation without remote state:

```sh
cd infra/stage
terraform init -backend=false
terraform validate
```

## Deploy a pushed image tag

Terraform consumes an explicit image tag. It does not build the image and does not infer a tag from Git.

### Step 1: get the bootstrapped ECR repository URL

Bootstrap creates the durable ECR repository before runtime apply:

```sh
cd infra/stage
terraform init -backend-config=backend.hcl
ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
ECR_REGISTRY=$(echo "$ECR_REPOSITORY_URL" | cut -d/ -f1)
```

### Step 2: authenticate Docker to ECR

```sh
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
```

### Step 3: build, tag, and push

From the lab root:

```sh
cd /path/to/labs/06-static-site-ecs
docker build -t cidr-calculator:v1 .
docker tag cidr-calculator:v1 "$ECR_REPOSITORY_URL:v1"
docker push "$ECR_REPOSITORY_URL:v1"
```

### Step 4: apply ECS Express service

Set `image_tag` in `infra/stage/stage.auto.tfvars`:

```hcl
image_tag = "v1"
```

Then apply:

```sh
cd infra/stage
terraform apply
```

### Step 5: verify the deployed service

```sh
cd infra/stage
SERVICE_URL=$(terraform output -raw service_url)
curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL"
# expected: 200
```

Open the HTTPS URL in a browser to confirm the CIDR calculator is live.

## Inspect ECS Express Mode

```sh
terraform output describe_express_service_command
terraform output monitor_express_service_command
terraform output cloudwatch_log_group_name
```

CloudWatch logs receive the Nginx container stdout/stderr stream.

## Migration notes from Lab 05

| Lab 05 EC2 | Lab 06 ECS Express Mode |
|---|---|
| EC2 instance with Docker installed by user-data | Managed Fargate service created by ECS Express Mode |
| Public HTTP instance URL | Managed HTTPS Express endpoint |
| EC2 instance profile | ECS task execution role, task role, infrastructure role |
| Security group on instance port 80 | Express Mode-managed load balancer and networking |
| Instance replacement on image tag change | Express service revision deployment |
| SSM Session Manager for host inspection | ECS service inspection and CloudWatch logs |

See `MIGRATION_DESIGN.md` for the full migration design, rollback plan, and validation checklist.

## Teardown

```sh
cd infra/stage
terraform destroy
```

Runtime destroy leaves the bootstrapped ECR repository and image history intact.
