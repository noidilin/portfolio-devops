# Lab 05 EC2 bootstrap

This Terraform root owns the durable AWS bootstrap for Lab 05 (Static Site on EC2): the canonical ECR repository plus the GitHub Actions OIDC roles CI/CD uses to plan, push images, and apply the disposable runtime stage. It is bootstrap infrastructure that must survive runtime create/destroy cycles, not runtime infrastructure.

Apply this root once (human first-apply) before CI/CD live plans or approved deploys are expected to work.

## Purpose

This root manages exactly the durable runtime CI/CD identity and artifact model for the lab:

- `aws_ecr_repository.service` — immutable, scan-on-push, AES256-encrypted ECR repository that holds the source-derived container images.
- `aws_ecr_lifecycle_policy.service` — keeps the most recent 20 `sha-` tagged images and expires untagged images after one day.
- `aws_iam_role.github_plan` — GitHub OIDC role for PR Terraform plans (read-only on the runtime stage, lock-only mutation).
- `aws_iam_role.github_image_push` — GitHub OIDC role for pushing immutable images from `main`.
- `aws_iam_role.github_apply` — GitHub OIDC role for approved apply/destroy jobs (runtime stage mutation).
- `aws_iam_policy.github_plan` / `github_image_push` / `github_apply` — least-privilege permissions attached to the matching roles.

The roles trust the shared account GitHub OIDC provider managed by `infra/bootstrap/aws`.

## Prerequisites

The following AWS account prerequisites are external to this root and are managed/documented as sandbox prerequisites, not by this Terraform:

- The S3 Terraform state bucket (account-specific; configured in the ignored local `backend.hcl`).
- The `lab-devops-permissions-boundary` permissions boundary.
- The `lab-gitops-oidc-apply-permissions-boundary` permissions boundary used by the GitHub apply role.
- The account GitHub OIDC provider for `token.actions.githubusercontent.com` (created by `infra/bootstrap/aws`).
- A GitHub Environment named `lab-05-stage` with required reviewers configured for approved apply/destroy.

See [`docs/aws-sandbox/`](../../../../docs/aws-sandbox/) for the sandbox IAM setup and permissions-boundary definitions.

## Configure backend and variables

Copy the backend example to the ignored local file and fill in your account-specific state bucket and region:

```sh
cd labs/05-static-site-ec2/infra/bootstrap
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl
```

`backend.hcl` is ignored by Git because it contains real account identifiers. Commit only `backend.hcl.example` with placeholder values.

This root has sensible defaults, so no `tfvars` file is required for a standard apply. Key variables with validation:

- `github_repository` (default `noidilin/portfolio-devops`) — `owner/repo` slug used in OIDC trust subjects.
- `environment` (default `stage`) — deployment environment name.
- `project_name` (default `static-site-ec2`) — feeds resource-name prefixes and tags.
- `service_name` (default `cidr-calculator`) — ECR repository and image artifact name.
- `github_environment` (default `lab-05-stage`) — GitHub Environment trusted to assume the apply role.
- `tags` (default `{}`) — additional tags merged into the common tag map.

## Validate and apply

Static checks (backend disabled, as CI runs them):

```sh
terraform -chdir=labs/05-static-site-ec2/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/05-static-site-ec2/infra/bootstrap init -backend=false
terraform -chdir=labs/05-static-site-ec2/infra/bootstrap validate
terraform -chdir=labs/05-static-site-ec2/infra/bootstrap test
```

Local apply with the operator's real backend:

```sh
cd labs/05-static-site-ec2/infra/bootstrap
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output
```

## Durable resources

The ECR repository, ECR lifecycle policy, GitHub OIDC roles, and their policies are durable bootstrap infrastructure. They must survive runtime create/destroy cycles for the lab. Only an explicit, intentional bootstrap-destroy operation should consider removing them, and only after the runtime stage has been torn down and CI/CD no longer needs the ECR image history.

The bootstrap root's own Terraform state (`labs/05-static-site-ec2/infra/bootstrap/terraform.tfstate`) is human/operator-managed and is intentionally not granted to any runtime CI role.

## CI/CD consumers

The runtime stage root (`labs/05-static-site-ec2/infra/stage`) and the GitHub Actions workflows consume this root's outputs:

- `ecr_repository_name` / `ecr_repository_url` — the canonical ECR repository image push/pull contract.
- `github_plan_role_arn` — assumed by PR-check CI for `terraform plan` on the runtime stage.
- `github_image_push_role_arn` — assumed by approved image-push jobs on `main`.
- `github_apply_role_arn` — assumed by approved deploy/destroy jobs gated by the `lab-05-stage` GitHub Environment.

Trust model (canonical across AWS runtime labs):

- Plan role trusts OIDC audience `sts.amazonaws.com` plus `pull_request` and `ref:refs/heads/main` subjects. No workflow-file-specific conditions.
- Image-push role trusts `ref:refs/heads/main` only.
- Apply role trusts the `environment:lab-05-stage` subject only.

State-access model (least privilege):

- Plan role reads the runtime stage state object and may mutate only its `.tflock` lock object; `s3:ListBucket` is scoped to the runtime stage prefix.
- Apply role may get/put/delete the runtime stage state object and its lock; `s3:ListBucket` is scoped to the runtime stage prefix.
- Neither role can reach the bootstrap state object or any prefix outside the runtime stage.

Lab workflows must request an OIDC token:

```yaml
permissions:
  id-token: write
  contents: read
```

and then assume the lab-specific role with `aws-actions/configure-aws-credentials`.

## Runtime destroy boundary

Runtime teardown (`labs/05-static-site-ec2/infra/stage` `terraform destroy`, or the `aws-runtime-destroy` workflow) removes only disposable workload resources such as the EC2 instance, instance profile, and security group. Runtime destroy must never remove this root's ECR repository, image history, GitHub OIDC roles, attached policies, permissions boundaries, or the Terraform state foundations.
