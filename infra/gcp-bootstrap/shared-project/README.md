# Shared GCP project bootstrap

For the end-to-end operator order and handoff checklist, see [`../README.md`](../README.md).

This Terraform root bootstraps the shared foundation for an already-created and billing-linked personal GCP project. It is the only local-state exception in the GCP lab stack: it creates the GCS bucket that later per-lab bootstrap and runtime roots use for remote state.

## What it manages

- Minimal project service APIs for the planned GCE and Cloud Run static-site labs.
- A regional, versioned GCS Terraform state bucket named `<project_id>-tf-state` by default.
- A monthly budget guardrail that sends alerts to the billing account's default IAM recipients.
- A shared GitHub Workload Identity Federation pool/provider scoped to one `OWNER/REPO` repository.
- Common lowercase labels for cross-cloud cost and ownership filtering.

It does **not** create the GCP project, link billing, create runtime resources, or create per-lab service accounts.

## First-run prerequisites

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

Terraform also declares these APIs so they remain managed after the first apply.

## Local ADC authentication

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

## Configure

```sh
cd infra/gcp-bootstrap/shared-project
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```

Use placeholders in committed files only. `terraform.tfvars` is ignored because it contains account-specific project and billing identifiers.

For non-USD billing accounts, set `budget_currency` to the billing account currency and set `budget_amount_units` to a local-currency amount that is roughly USD $10.

## Validate and apply

This root intentionally has no `backend` block. Its local state is the bootstrap exception because it creates the shared GCS state bucket.

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

The state bucket has `prevent_destroy = true`, uniform bucket-level access, public access prevention, and object versioning enabled.

## Later GCS state usage

After this root is applied, later GCP roots should use the `state_bucket_name` output as their GCS backend bucket and a purpose-specific prefix such as:

```text
gcp/bootstrap/labs/07-static-site-gce/
gcp/bootstrap/labs/08-static-site-cloud-run/
gcp/runtime/labs/07-static-site-gce/stage/
gcp/runtime/labs/08-static-site-cloud-run/stage/
```

The WIF outputs expose the provider and principal-set identifiers needed by later per-lab bootstrap roots and GitHub Actions workflows.
