# Lab 08 Cloud Run bootstrap

This Terraform root creates durable resources for the future Lab 08 Cloud Run static-site runtime. Runtime destroys should leave these resources intact: canonical ECR image history, the GCP Artifact Registry mirror, CI identities, and GCS-backed Terraform state.

## Purpose

Bootstrap owns the durable dual-cloud contract for Lab 08: AWS image roles and ECR, GCP Artifact Registry, GCP plan/apply service accounts, WIF impersonation, least-privilege state access, and outputs consumed by CI/CD and runtime Terraform.

## Prerequisites

1. Apply `infra/bootstrap/gcp` first.
2. Use its `state_bucket_name`, `github_wif_pool_name`, and `github_wif_provider_name` outputs here.
3. Ensure AWS sandbox prerequisites exist, including the shared GitHub OIDC provider and permissions boundary policy documented under `docs/aws-sandbox/`.
4. Run the first bootstrap apply as a human/bootstrap operator with permission to create Artifact Registry repositories, custom roles, service accounts, project IAM members, service-account IAM members, and state-bucket IAM members. The root intentionally does not create an unused bootstrap-admin custom role.
5. Keep account-specific values in ignored local files only.

## Configure backend and variables

```sh
cd labs/08-static-site-cloud-run/infra/bootstrap
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl # set bucket to shared state_bucket_name
cp bootstrap.auto.tfvars.example bootstrap.auto.tfvars
$EDITOR bootstrap.auto.tfvars
```

The backend prefix is `gcp/bootstrap/labs/08-static-site-cloud-run`, so this root uses the shared GCS bucket created by the shared GCP bootstrap.

The committed variable example uses placeholders only and expects the shared bootstrap outputs `project_id`, `project_number`, `state_bucket_name` (as `gcp_state_bucket_name`), `github_wif_pool_name`, and `github_wif_provider_name`. It consumes full shared WIF resource names, not pool/provider IDs.

## Validate and apply

Static checks (backend disabled, as CI runs them):

```sh
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap init -backend=false
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap validate
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap test
```

Local apply with the operator's real backend and shared-project outputs:

```sh
cd labs/08-static-site-cloud-run/infra/bootstrap
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output
```

## Durable resources

- ECR repository in `ap-northeast-1` using immutable tags, scan-on-push, AES256 encryption, and hard-coded lab lifecycle defaults.
- Artifact Registry Docker repository in `asia-northeast1` with cleanup policies to keep recent image versions, delete old `sha-*` tags, and delete untagged images.
- Canonically named GCP plan/apply service accounts: `devops-cloudrun-<environment>-plan` and `devops-cloudrun-<environment>-apply`.
- Project custom roles for pragmatic Cloud Run planning/apply permissions without broad Editor-like grants; bootstrap pre-creates the dedicated Cloud Run runtime service account so runtime deploys only need `iam.serviceAccounts.actAs`.
- Additive GitHub WIF impersonation members: plan allows explicit pull-request and main subjects; apply allows only the protected `lab-08-stage` GitHub Environment subject.
- GCS state IAM: plan can read state and mutate only `.tflock` files under bootstrap/runtime prefixes; apply can read/list state for Terraform GCS backend workspace discovery and mutate objects only under the runtime prefix.

## CI/CD consumers

CI/CD consumes these outputs and constants:

- `github_plan_role_arn`, `github_image_push_role_arn`, and `github_image_pull_role_arn` for AWS OIDC/ECR access.
- `github_wif_provider_name`, `gcp_plan_service_account_email`, and `gcp_apply_service_account_email` for GCP WIF authentication.
- `artifact_registry_image_base`, `gcp_runtime_service_account_email`, `gcp_state_bucket_name`, and `gcp_runtime_state_prefix` for image mirroring and runtime Terraform.

Affected workflows use `devops-cloudrun-stage-plan@portfolio-devops-labs.iam.gserviceaccount.com` for PR/main planning and `devops-cloudrun-stage-apply@portfolio-devops-labs.iam.gserviceaccount.com` for protected deploy/destroy jobs.

## Runtime destroy boundary

Runtime deploy/destroy workflows must target `labs/08-static-site-cloud-run/infra/stage` and the runtime state prefix `gcp/runtime/labs/08-static-site-cloud-run/<environment>/`. Do not destroy this bootstrap root during normal runtime cleanup; it owns durable repositories, identities, trust bindings, and state access.
