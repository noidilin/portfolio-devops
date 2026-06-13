# Lab 08 Cloud Run bootstrap

This Terraform root creates durable resources for the future Lab 08 Cloud Run static-site runtime. Runtime destroys should leave these resources intact: canonical ECR image history, the GCP Artifact Registry mirror, CI identities, and GCS-backed Terraform state.

## Prerequisites

1. Apply `infra/gcp-bootstrap/shared-project` first.
2. Use its `state_bucket_name`, `github_wif_pool_id`, and `github_wif_provider_id` outputs here.
3. Keep account-specific values in ignored local files only.

## Configure remote state

```sh
cd labs/08-static-site-cloud-run/infra/bootstrap
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl # set bucket to shared state_bucket_name
terraform init -backend-config=backend.hcl
```

The backend prefix is `gcp/bootstrap/labs/08-static-site-cloud-run`, so this root uses the shared GCS bucket created by the shared GCP bootstrap.

## Configure variables

```sh
cp bootstrap.auto.tfvars.example bootstrap.auto.tfvars
$EDITOR bootstrap.auto.tfvars
```

The committed example uses placeholders only.

## Validate

```sh
terraform fmt -recursive
terraform validate
terraform test
```

For local syntax-only validation before configuring remote state:

```sh
terraform init -backend=false
terraform validate
```

## Durable resources

- ECR repository in `ap-northeast-1` using the existing lab naming style, immutable tags, scan-on-push, AES256 encryption, and SHA-tag lifecycle retention.
- Artifact Registry Docker repository in `asia-northeast1` with cleanup policies to keep recent image versions and remove untagged images.
- Lab-specific GCP plan and apply service accounts.
- Project custom roles for pragmatic Cloud Run planning/apply permissions without broad Editor-like grants.
- GitHub WIF impersonation: plan is repository-scoped; apply is scoped to the protected `lab-08-stage` GitHub Environment subject.
- Outputs for CI/CD and future runtime Terraform: ECR URLs, Artifact Registry image base, service account emails, WIF provider/principals, custom role IDs, and recommended runtime state prefix.
