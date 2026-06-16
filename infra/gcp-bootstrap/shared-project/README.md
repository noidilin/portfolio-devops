# Shared GCP project bootstrap

This Terraform root bootstraps the shared foundation for an already-created and billing-linked personal GCP project. It is the only local-state exception in the GCP lab stack: it creates the GCS bucket that later per-lab bootstrap and runtime roots use for remote state.

For the end-to-end operator order, see [`../README.md`](../README.md) and [`../../README.md`](../../README.md).

## Purpose

This root manages durable shared GCP project foundations:

- Minimal project service APIs for the GCE and Cloud Run static-site labs.
- A regional, versioned GCS Terraform state bucket named `<project_id>-tf-state` by default.
- A monthly budget guardrail that sends alerts to the billing account's default IAM recipients.
- A shared GitHub Workload Identity Federation pool/provider scoped to one `OWNER/REPO` repository.
- Common lowercase labels for cross-cloud cost and ownership filtering.

It does not create the GCP project, link billing, create runtime resources, create per-lab service accounts, or manage GitHub Environment reviewer settings.

## Prerequisites

First-run human prerequisites:

1. Create the GCP project manually.
2. Link the billing account manually.
3. Grant the human bootstrap user Project Owner on the project.
4. Ensure the same user can create budgets on the billing account.
5. Enable the first-run APIs needed for Terraform to manage the rest:

```sh
gcloud services enable \
  serviceusage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  billingbudgets.googleapis.com \
  --project YOUR_EXISTING_GCP_PROJECT_ID
```

Use local user Application Default Credentials for this bootstrap only. Do not create or download service account keys.

```sh
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_EXISTING_GCP_PROJECT_ID
gcloud config set compute/region asia-northeast1
gcloud config set compute/zone asia-northeast1-a
gcloud auth application-default set-quota-project YOUR_EXISTING_GCP_PROJECT_ID
```

The Terraform provider also sets `billing_project` and `user_project_override` to the target project so APIs such as Cloud Billing Budgets do not accidentally use a stale ADC quota project.

## Configure backend and variables

This root intentionally has no remote `backend` block. Its local state is the bootstrap exception because it creates the shared GCS state bucket consumed by later roots.

Configure account/project-specific inputs locally:

```sh
cd infra/gcp-bootstrap/shared-project
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```

`terraform.tfvars` is ignored because it contains project and billing identifiers. Commit placeholders only in `terraform.tfvars.example`.

For non-USD billing accounts, set `budget_currency` to the billing account currency and set `budget_amount_units` to a local-currency amount that is roughly USD $10.

## Validate and apply

Static checks:

```sh
terraform -chdir=infra/gcp-bootstrap/shared-project fmt -check -recursive
terraform -chdir=infra/gcp-bootstrap/shared-project init -backend=false
terraform -chdir=infra/gcp-bootstrap/shared-project validate
terraform -chdir=infra/gcp-bootstrap/shared-project test
```

Local first apply with the operator's ADC credentials:

```sh
cd infra/gcp-bootstrap/shared-project
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

The state bucket has `prevent_destroy = true`, uniform bucket-level access, public access prevention, and object versioning enabled.

## Durable resources

The APIs, state bucket, budget guardrail, WIF pool/provider, and shared labels are durable shared bootstrap resources. They must survive normal Lab 07/08 runtime create/destroy cycles and per-lab bootstrap changes.

Only an explicit shared-bootstrap teardown should consider removing them, and only after every per-lab bootstrap/runtime root depending on the shared state bucket and WIF provider has been intentionally removed.

## CI/CD consumers

Per-lab bootstrap roots and GitHub Actions consume these outputs:

- `project_id` and `project_number` — project identity for lab roots and WIF principals.
- `state_bucket_name` — passed to per-lab bootstrap as `gcp_state_bucket_name` and used by runtime GCS backends.
- `github_wif_pool_name` and `github_wif_provider_name` — full resource names consumed directly by Labs 07/08 bootstrap roots and GitHub Actions auth.
- `github_repository` — repository slug used for explicit PR/main/protected-environment trust subjects.

Later GCP roots use the shared state bucket with purpose-specific prefixes such as:

```text
gcp/bootstrap/labs/07-static-site-gce/
gcp/bootstrap/labs/08-static-site-cloud-run/
gcp/runtime/labs/07-static-site-gce/stage/
gcp/runtime/labs/08-static-site-cloud-run/stage/
```

The per-lab plan service accounts can read state and mutate only `.tflock` files under their bootstrap/runtime prefixes. Runtime apply service accounts are scoped to runtime prefixes only.

## Runtime destroy boundary

Runtime deploy/destroy workflows must never destroy this shared bootstrap root or its local state. Routine runtime teardown is scoped to the Lab 07/08 `infra/stage` roots and the `gcp/runtime/...` state prefixes. The shared GCS state bucket, WIF pool/provider, budget guardrail, and managed API foundation remain in place for future plans, deploys, and destroys.
