# Lab 05: Static Site on EC2

Terraform tracer bullet for a single EC2-hosted Docker service runtime path.

## Infrastructure

- Reusable module: `infra/modules/ec2-docker-runtime`
- Stage root: `infra/stage`

The stage root provisions:

- an ECR repository for the `cidr-calculator` image artifact
- one public EC2 instance in the default VPC/subnets
- an IAM instance profile for SSM Session Manager and ECR image pulls
- a security group with public HTTP ingress on port 80, no SSH ingress, and outbound access
- outputs for image push commands, HTTP access, and SSM inspection

## Backend and variables pattern

This lab uses the `backend.hcl` pattern for backend settings and `.auto.tfvars` for normal Terraform input variables.

Backend config is loaded by `terraform init`, so it cannot come from `.auto.tfvars`.

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

## Test commands

Preview changes:

```sh
cd infra/stage
terraform fmt -recursive ../..
terraform validate
terraform plan
```

Create infrastructure:

```sh
terraform apply
```

Inspect useful commands/URLs:

```sh
terraform output
```

Destroy lab resources:

```sh
terraform destroy
```
