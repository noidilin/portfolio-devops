# Terraform Remote Backend Management: Separating State Configuration from Infrastructure Configuration

When I started wiring the Terraform root for this EC2 lab, I wanted something simple: a reusable module under `infra/modules`, a stage root under `infra/stage`, and a way to make the state remote without hard-coding every account-specific detail into the Terraform files.

The confusing part was not S3 itself. The confusing part was **where each piece of configuration belongs**.

I had two files that looked similar at first glance:

- `backend.hcl`
- `stage.auto.tfvars`

Both contain values. Both are local configuration files. Both affect how Terraform behaves. But they are loaded at different times, for different purposes.

That distinction became the main lesson of this lab.

## What I wanted to understand

I wanted a clean answer to a few questions:

1. How should I configure an S3 remote backend without committing machine/account-specific values directly into `backend.tf`?
2. Why can't backend settings use normal Terraform variables?
3. What should live in `backend.hcl`, and what should live in `.auto.tfvars`?
4. What commands should I use to test the Terraform root safely?

The mental model I ended up with is this:

> `backend.hcl` configures Terraform's storage and locking.  
> `.auto.tfvars` configures the infrastructure Terraform will create.

One file answers, "Where does Terraform keep its memory?"  
The other answers, "What should Terraform build?"

## The backend block is intentionally incomplete

In this lab, the stage root has a small `backend.tf`:

```hcl
terraform {
  # Backend settings live in backend.hcl, loaded during terraform init:
  # terraform init -backend-config=backend.hcl
  backend "s3" {}
}
```

At first, an empty backend block can feel strange. It declares an S3 backend, but does not say which bucket, key, region, or lock table to use.

That is deliberate.

The backend block says:

> This root module expects to use S3 for state.

The actual environment-specific backend values come from `backend.hcl` during initialization.

```hcl
# backend.hcl
bucket         = "noidilin-tf-state"
key            = "labs/05-static-site-ec2/infra/stage/terraform.tfstate"
region         = "ap-northeast-1"
dynamodb_table = "noidilin-tf-state-locks"
encrypt        = true
```

Then Terraform is initialized with:

```sh
terraform init -backend-config=backend.hcl
```

This wires the root to remote state:

- state is stored in the S3 bucket `noidilin-tf-state`
- the object path is `labs/05-static-site-ec2/infra/stage/terraform.tfstate`
- the AWS region is `ap-northeast-1`
- DynamoDB is used for state locking
- state is encrypted at rest

This follows the same general pattern as my earlier `01-single-web-server` lab, but moves the backend values out of committed Terraform code and into a local `backend.hcl` file.

## Why `.auto.tfvars` cannot configure the backend

My initial temptation was to ask whether `.auto.tfvars` could manage the backend too. It already loads variable values automatically, so it feels like a natural place to put things like `state_bucket` or `state_key`.

But Terraform's lifecycle makes that impossible.

Terraform must initialize the backend before it can evaluate normal input variables.

The order is roughly:

```text
terraform init
  -> read backend.tf
  -> read backend config passed with -backend-config
  -> configure remote state
  -> install providers/modules

terraform plan/apply
  -> load variables.tf
  -> auto-load *.auto.tfvars
  -> evaluate providers, modules, resources
  -> read/write state through the already-configured backend
```

So this kind of configuration does not work:

```hcl
terraform {
  backend "s3" {
    bucket = var.state_bucket # invalid
  }
}
```

The variable system is not available yet. Backend initialization happens before that world exists.

That boundary is easy to forget because Terraform files all use the same language. But backend configuration is not normal resource configuration. It is part of Terraform bootstrapping itself.

## What belongs in `stage.auto.tfvars`

The `.auto.tfvars` file is still useful, just for a different layer.

For this lab, `stage.auto.tfvars` contains values like:

```hcl
aws_region   = "ap-northeast-1"
environment  = "stage"
project_name = "static-site-ec2"
service_name = "cidr-calculator"

http_ingress_cidr_blocks = ["0.0.0.0/0"]
subnet_id = null
ecr_force_delete = false
```

These values configure the actual infrastructure.

For example, the AWS provider uses `aws_region`:

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.default_tags
  }
}
```

The module uses values such as `service_name`, `instance_type`, and HTTP ingress CIDRs to decide what to create.

That means `.auto.tfvars` belongs to the plan/apply phase. It controls the shape of the desired infrastructure, not where Terraform stores state.

## The file pattern I settled on

The committed files should be safe templates and reusable Terraform code:

```text
infra/
  modules/
    ec2-docker-runtime/
  stage/
    backend.tf
    backend.hcl.example
    stage.auto.tfvars.example
    providers.tf
    variables.tf
    main.tf
    outputs.tf
```

The local files should contain environment/account-specific values:

```text
infra/stage/backend.hcl
infra/stage/stage.auto.tfvars
```

Those local files should not be committed.

The `.gitignore` keeps that boundary explicit:

```gitignore
*.tfvars
!*.tfvars.example
backend.hcl
!backend.hcl.example
*.tfstate
*.tfstate.*
**/.terraform/*
```

This gives me a small but useful convention:

- commit `backend.hcl.example`
- copy it to `backend.hcl` locally
- commit `stage.auto.tfvars.example`
- copy it to `stage.auto.tfvars` locally
- keep real backend/state/input values out of git unless there is a clear reason to share them

## Testing the Terraform root

For local syntax validation without touching the remote backend, I can initialize with backend disabled:

```sh
cd infra/stage
terraform init -backend=false
terraform validate
```

This is useful when I only want to check that the Terraform configuration is structurally valid.

For the real remote-backend workflow:

```sh
cd infra/stage
cp backend.hcl.example backend.hcl
cp stage.auto.tfvars.example stage.auto.tfvars
terraform init -backend-config=backend.hcl
terraform validate
terraform plan
```

If the directory was previously initialized with `-backend=false`, then switching to S3 should use reconfiguration:

```sh
terraform init -reconfigure -backend-config=backend.hcl
```

Once the plan looks right:

```sh
terraform apply
terraform output
```

And for cleanup:

```sh
terraform destroy
```

## Why this matters

Remote state is one of those Terraform topics that can look like plumbing until it breaks. Then it becomes clear that state is not just an implementation detail. It is Terraform's memory of reality.

Putting that memory in S3 gives me a shared and durable place for state. Adding DynamoDB locking protects against two Terraform runs trying to change the same infrastructure at once. Separating backend config from normal input variables makes the lifecycle easier to reason about.

The small lesson from this lab is that not all configuration belongs to the same phase.

- `backend.hcl` is for Terraform initialization.
- `stage.auto.tfvars` is for Terraform evaluation.
- `backend.tf` declares the backend type.
- the state key encodes the environment/component boundary.

That boundary makes the project less magical. Terraform is still doing a lot behind the scenes, but at least I now know which file is responsible for which part of the process.

The next question I want to explore is how this pattern should evolve when there are multiple environments and multiple independently deployed components. The state key naming starts simple, but it eventually becomes part of the architecture too.
