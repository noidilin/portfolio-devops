# Lab 07 GCE bootstrap

Durable bootstrap resources for Lab 07 (Static Site on GCE). Runtime destroys must not remove this root because it owns image history, CI identities, state access, and durable WIF bindings.

## Purpose

This root owns the durable CI/CD bootstrap contract for the lab:

- `aws_ecr_repository.service` — immutable, scan-on-push, AES-256 encrypted ECR repository for canonical container images.
- `aws_ecr_lifecycle_policy.service` — keeps the most recent 20 SHA-tagged images and expires untagged images after one day.
- `aws_iam_role.github_plan` — GitHub OIDC role for PR/main Terraform plans.
- `aws_iam_role.github_image_push` — GitHub OIDC role for image pushes from `main`.
- `aws_iam_role.github_image_pull` — GitHub OIDC role for image pulls from protected deployment jobs.
- `google_artifact_registry_repository.service` — canonical artifact mirror repository in GCP.
- `google_service_account.plan` / `google_service_account.apply` — GCP plan/apply identities.
- `google_project_iam_custom_role.plan` / `google_project_iam_custom_role.apply` — least-privilege custom roles bound to the plan/apply service accounts.
- `google_storage_bucket_iam_member.*` — state read/lock grants for bootstrap and runtime prefixes.
- `google_service_account_iam_member.*` — additive WIF trust for explicit PR/main/apply principals.

## Prerequisites

This lab requires:

- `infra/gcp-bootstrap/shared-project` already applied (or planned and ready to apply).
- `aws` account-level GitHub OIDC provider and permissions boundaries managed outside this root.
- Shared GCP bootstrap outputs: `project_id`, `project_number`, `state_bucket_name`, `github_wif_pool_name`, `github_wif_provider_name`. Pass `state_bucket_name` as this root's `gcp_state_bucket_name`.
- A GitHub Environment named `lab-07-stage` for apply protections.

## Configure backend and variables

```sh
cd labs/07-static-site-gce/infra/bootstrap
cp backend.hcl.example backend.hcl
cp bootstrap.auto.tfvars.example bootstrap.auto.tfvars
$EDITOR backend.hcl bootstrap.auto.tfvars
```

`backend.hcl` is ignored because it contains account/project-specific values. Use non-default values in `bootstrap.auto.tfvars` only locally.

Key validated variables include:

- `github_repository` (`noidilin/portfolio-devops` default) — OIDC trust slug.
- `environment` (`stage` default).
- `project_name` (`static-site-gce` default).
- `service_name` (`cidr-calculator` default).
- `github_environment` (`lab-07-stage` default).
- `gcp_state_bucket_name` (`shared project bucket` default in example).
- `artifact_registry_keep_count`, `artifact_registry_delete_older_than`, `artifact_registry_untagged_delete_older_than`.
- `aws_tags` and `gcp_labels` maps for optional metadata.

## Validate and apply

Static checks (backend disabled, as CI runs them):

```sh
terraform -chdir=labs/07-static-site-gce/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/07-static-site-gce/infra/bootstrap init -backend=false
terraform -chdir=labs/07-static-site-gce/infra/bootstrap validate
terraform -chdir=labs/07-static-site-gce/infra/bootstrap test
```

Local apply with the operator's real backend and shared-project outputs:

```sh
cd labs/07-static-site-gce/infra/bootstrap
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output
```

## Durable resources

The durable resources in this root should outlive runtime destroy/apply cycles:

- AWS ECR repository and lifecycle policy.
- GitHub OIDC roles and policies.
- GCP Artifact Registry mirror repository.
- GCP plan/apply service accounts and roles.
- GCP state-read/lock IAM grants.
- GCP WIF trust bindings.

The bootstrap state for this root is human/operator managed and remains excluded from routine runtime destroy workflows.

## CI/CD consumers

- `gcp-bootstrap-ci.yml` validates per-lab bootstrap plans for this root using PR/main and plan service identities.
- Runtime deploy/destroy workflows use:
  - `gcp_plan_service_account`: `devops-gce-stage-plan@portfolio-devops-labs.iam.gserviceaccount.com`
  - `gcp_apply_service_account`: `devops-gce-stage-apply@portfolio-devops-labs.iam.gserviceaccount.com`

State-access model:

- Plan role reads state via plan-service-account bucket-level read (`roles/storage.objectViewer`) and lock mutation only on `.tflock` files in:
  - `gcp/bootstrap/labs/07-static-site-gce/`
  - `gcp/runtime/labs/07-static-site-gce/stage/`
- Apply role gets state write access only for runtime state prefix `gcp/runtime/labs/07-static-site-gce/stage/`.

## Runtime destroy boundary

Routine runtime teardown removes only disposable resources in `labs/07-static-site-gce/infra/stage`:

- Compute instance, networking, runtime service account, firewall rules, and instance-level policies.

It must not destroy this bootstrap root or its state grants/state resources.
