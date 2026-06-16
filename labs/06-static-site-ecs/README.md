# Lab 06: Static Site on ECS Express Mode

Terraform tracer bullet for migrating the Lab 05 EC2 Docker runtime to Amazon ECS Express Mode.

The lab deploys the shared CIDR Calculator static-site container to ECS Express Mode. The shared app under `../../apps/cidr-calculator/` owns the React/Vite SPA, package metadata, Dockerfile, and Nginx runtime config. This lab owns only the ECS runtime infrastructure, ECR repository boundary, and Terraform stage that deploys an explicit image tag.

ECS Express Mode manages the Fargate service, HTTPS endpoint, load balancer, target groups, security groups, deployment flow, auto scaling, and CloudWatch integration.

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

- Reusable module: `infra/modules/ecs-express-static-site`
- Stage root: `infra/stage`

The stage root expects a bootstrapped ECR repository and provisions:

- an ECS cluster
- ECS task execution, task, and infrastructure IAM roles with the lab permissions boundary
- a CloudWatch log group
- an ECS Express Gateway service using the ECR image tag you provide
- outputs for image push commands, service inspection, logs, and HTTPS access

### Backend and variables pattern

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

This lab has GitHub Actions support for PR checks, main/manual approved deploys, and manual approved destroys. Bootstrap resources live outside the disposable runtime:

- shared OIDC provider: `infra/bootstrap/aws/`
- lab bootstrap: `infra/bootstrap/` (ECR plus GitHub OIDC roles)
- runtime: `infra/stage/` (ECS Express service only)

Create GitHub Environment `lab-06-stage` before using deploy/destroy, and configure its required reviewers in the GitHub repository settings. The PR-check CI workflow runs app lint/test/build, a Docker local smoke test from `apps/cidr-calculator`, Terraform validation, `terraform test`, and a Terraform plan; it does not push images to ECR. The deploy workflow reruns the checks, pushes or reuses this lab's ECR image as `sha-${GITHUB_SHA}`, then applies only Runtime Stage resources in `infra/stage` with that image tag after environment approval. Dispatch `Lab container deploy` from `main`, choose `06-static-site-ecs`, and approve the environment gate. Shared app changes on `main` select the approved deployment paths for both Lab 05 and Lab 06. Dispatch `Lab container destroy` to destroy only the ECS runtime. Destroy removes only Runtime Stage resources; Bootstrap resources survive, including the ECR repository and image history, GitHub OIDC cloud identities/roles, ECS runtime IAM roles, permissions boundaries, and Terraform state foundations.

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

### Step 3: build the shared app image, tag it for Lab 06 ECR, and push

From the shared app root:

```sh
cd /path/to/apps/cidr-calculator
docker build -t cidr-calculator:v1 .
docker tag cidr-calculator:v1 "$ECR_REPOSITORY_URL:v1"
docker push "$ECR_REPOSITORY_URL:v1"
```

You can also get ready-to-run commands from Terraform. Run them from `labs/06-static-site-ecs/infra/stage`; the generated Docker build command points back to the shared app context:

```sh
cd /path/to/labs/06-static-site-ecs/infra/stage
terraform output docker_build_tag_push_commands
```

### Step 4: request Approved Deploy for the ECS Express service

The normal deploy path is the `ec2-ecs-deploy` GitHub Actions workflow. Dispatch `Lab container deploy` from `main`, choose `06-static-site-ecs`, and approve the `lab-06-stage` GitHub Environment gate. The workflow passes the immutable `sha-${GITHUB_SHA}` image tag into Terraform and applies only the Runtime Stage.

For plan-only local inspection, set `image_tag` in `infra/stage/stage.auto.tfvars` and run `terraform plan`; do not use local apply as the learner provisioning path.

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

## Teardown

Use the `ec2-ecs-destroy` GitHub Actions workflow for approved runtime teardown. Dispatch `Lab container destroy`, choose `06-static-site-ecs`, and approve the `lab-06-stage` GitHub Environment gate.

Destroy removes only Runtime Stage resources such as the ECS Express service, cluster, CloudWatch log group, and runtime IAM roles. Bootstrap resources survive runtime destroy, including the ECR repository and image history, GitHub OIDC cloud identities/roles, permissions boundaries, and Terraform state foundations.
