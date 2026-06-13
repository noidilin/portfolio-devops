# Lab 07 GCE bootstrap

Durable bootstrap resources for the future GCE static-site runtime lab. Runtime destroys should not remove this root because it owns image history, CI identities, and state access.

## What it manages

- Canonical AWS ECR repository for `cidr-calculator`, using immutable tags, scan on push, AES-256 encryption, and the same SHA/untagged lifecycle intent as the existing container labs.
- GCP Artifact Registry Docker repository in the default GCP region for mirrored images consumed by GCE.
- Artifact Registry cleanup policies that delete older `sha-` tags while keeping the most recent image versions.
- Separate GCP plan/apply service accounts.
- Pragmatic custom GCP plan/apply roles for Lab 07 bootstrap and future GCE runtime Terraform.
- GitHub WIF impersonation bindings: plan from PR/main contexts, apply only from the protected `lab-07-stage` environment.
- Outputs for image locations, service accounts, custom roles, WIF provider references, and future runtime state prefixes.

## Prerequisites

1. Apply `infra/gcp-bootstrap/shared-project` first.
2. Use its outputs for `gcp_project_id`, `gcp_project_number`, `state_bucket_name`, `github_wif_pool_name`, and `github_wif_provider_name`.
3. Ensure the AWS account-level GitHub OIDC provider and permissions boundary already exist.

## Configure

```sh
cd labs/07-static-site-gce/infra/bootstrap
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
$EDITOR backend.hcl terraform.tfvars
```

Committed examples use placeholders only. Keep real project/account values in ignored local files.

## Validate and apply

```sh
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
