# GCP bootstrap runbook and handoff

This runbook is the operator handoff for the GCP foundation used by the future static-site GCE and Cloud Run labs. It assumes the GCP project already exists and is already linked to billing; Terraform manages resources inside that project, not project creation or billing-account linkage.

Use placeholder values in committed files only. Put real project IDs, project numbers, billing account IDs, account numbers, service account emails, and local paths in ignored local files such as the shared root's `terraform.tfvars`, per-lab `bootstrap.auto.tfvars`, and `backend.hcl`.

## Bootstrap order

1. **Manual GCP project setup**
   - Create or choose an existing personal GCP project.
   - Link the billing account manually.
   - Grant the human bootstrap user enough project and billing permissions for first-run setup. Project Owner on the lab project plus budget creation access on the billing account is the intended short-lived bootstrap posture.
   - Enable only the APIs needed before Terraform can manage the rest:

   ```sh
   gcloud services enable \
     serviceusage.googleapis.com \
     cloudresourcemanager.googleapis.com \
     iam.googleapis.com \
     billingbudgets.googleapis.com \
     --project YOUR_EXISTING_GCP_PROJECT_ID
   ```

2. **Local ADC for shared bootstrap**
   - Authenticate the human operator locally:

   ```sh
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project YOUR_EXISTING_GCP_PROJECT_ID
   gcloud config set compute/region asia-northeast1
   gcloud config set compute/zone asia-northeast1-a
   gcloud auth application-default set-quota-project YOUR_EXISTING_GCP_PROJECT_ID
   ```

   The shared root intentionally uses user Application Default Credentials and local Terraform state because it creates the GCS bucket that every later GCP root uses for remote state. Do not create or download service account keys. The Google provider is configured with `billing_project = var.project_id` and `user_project_override = true` so ADC quota/billing attribution goes to the bootstrapped project instead of any stale local quota project.

3. **Apply shared project bootstrap**
   - Configure from placeholders:

   ```sh
   cd infra/gcp-bootstrap/shared-project
   cp terraform.tfvars.example terraform.tfvars
   $EDITOR terraform.tfvars
   terraform init
   terraform fmt -check -recursive
   terraform validate
   terraform test
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   terraform output
   ```

   Keep the generated local `terraform.tfstate` private. This first-run exception owns the durable state bucket, minimal project APIs, budget guardrail, shared GitHub Workload Identity Federation pool/provider, and common labels.

4. **Apply per-lab durable bootstrap**
   - Use shared bootstrap outputs to fill each lab's ignored backend and variable files.
   - Lab 07 GCE:

   ```sh
   cd labs/07-static-site-gce/infra/bootstrap
   cp backend.hcl.example backend.hcl
   cp bootstrap.auto.tfvars.example bootstrap.auto.tfvars
   $EDITOR backend.hcl bootstrap.auto.tfvars
   terraform init -backend-config=backend.hcl
   terraform fmt -check -recursive
   terraform validate
   terraform test
   terraform plan
   terraform apply
   terraform output
   ```

   - Lab 08 Cloud Run:

   ```sh
   cd labs/08-static-site-cloud-run/infra/bootstrap
   cp backend.hcl.example backend.hcl
   cp bootstrap.auto.tfvars.example bootstrap.auto.tfvars
   $EDITOR backend.hcl bootstrap.auto.tfvars
   terraform init -backend-config=backend.hcl
   terraform fmt -check -recursive
   terraform validate
   terraform test
   terraform plan
   terraform apply
   terraform output
   ```

5. **Future runtime roots**
   - Runtime Terraform should consume the per-lab bootstrap outputs and use the same shared GCS state bucket with runtime-specific prefixes.
   - Runtime destroy must remove only disposable workload resources. It must not destroy the bootstrap roots or their durable resources.

## Placeholder values to replace locally

Copy example files, then replace these placeholders only in ignored local files:

- `YOUR_EXISTING_GCP_PROJECT_ID`
- `000000000000` or another placeholder project number
- `YOUR_BILLING_ACCOUNT_ID`
- `OWNER/REPO`
- `YOUR_AWS_ACCOUNT_ID`
- Placeholder backend bucket names such as `your-existing-gcp-project-id-tf-state`
- Placeholder service account emails or role ARNs shown in examples

Do not commit the filled files. If a workflow needs real values, prefer GitHub repository/environment variables or secrets over committed literals.

## Remote state boundaries

- `infra/gcp-bootstrap/shared-project` has no backend block and keeps local state by design. It is the bootstrap exception because it creates the shared GCS Terraform state bucket.
- `labs/07-static-site-gce/infra/bootstrap` uses `backend.hcl` with the shared bucket and prefix `gcp/bootstrap/labs/07-static-site-gce`.
- `labs/08-static-site-cloud-run/infra/bootstrap` uses `backend.hcl` with the shared bucket and prefix `gcp/bootstrap/labs/08-static-site-cloud-run`.
- Future runtime roots should use prefixes such as:

```text
gcp/runtime/labs/07-static-site-gce/stage
gcp/runtime/labs/08-static-site-cloud-run/stage
```

## Durable resources that must survive runtime destroy

Runtime teardown must leave these intact:

- Shared GCS Terraform state bucket and its versioned object history.
- Shared GitHub Workload Identity Federation pool/provider.
- Per-lab GCP plan/apply service accounts and IAM bindings.
- Per-lab GCP custom roles.
- Per-lab AWS IAM roles for GitHub OIDC.
- Per-lab ECR repositories, lifecycle policies, and image history.
- Per-lab Artifact Registry repositories, cleanup policies, and mirrored image history.

Only an explicit bootstrap-destroy operation should consider removing those resources, and the shared state bucket has `prevent_destroy` protection.

## Dual-cloud image foundation

The image source of truth remains AWS ECR. Each GCP lab has:

- An **ECR canonical repository** in the AWS lab account/region using the existing static-site lab naming style and immutable SHA tags.
- An **Artifact Registry mirror repository** in the GCP region for GCE or Cloud Run to pull from GCP-native image paths.

CI should build or reference immutable `sha-<git-sha>` images, push canonical images to ECR through AWS OIDC, then mirror those images into Artifact Registry through GCP WIF-authenticated jobs.

## Outputs for future runtime labs

Shared bootstrap outputs consumed by per-lab bootstrap and future workflows:

- `project_id`
- `project_number`
- `default_region`
- `default_zone`
- `state_bucket_name`
- `github_repository`
- `github_wif_pool_id`
- `github_wif_pool_name`
- `github_wif_provider_id`
- `github_wif_provider_name`
- `github_wif_principal_set`
- `common_labels`

Per-lab outputs consumed by future GCE and Cloud Run runtime roots/workflows:

- ECR repository name, URL, ARN where exposed.
- AWS GitHub OIDC role ARNs for plan, image push, and apply where exposed.
- Artifact Registry repository ID/name.
- Artifact Registry image base path; append `:sha-<git-sha>` for immutable deployment.
- GCP plan/apply service account emails.
- GCP custom role names/IDs.
- WIF provider and trusted principal/principal-set values.
- Shared state bucket name.
- Recommended runtime state prefix.

## CI authentication model

- **AWS authority:** GitHub Actions uses GitHub OIDC with `aws-actions/configure-aws-credentials` to assume lab-specific AWS roles. Those roles own ECR canonical repository access and any AWS-side bootstrap checks.
- **GCP authority:** GitHub Actions uses `google-github-actions/auth` to exchange the GitHub OIDC token through GCP Workload Identity Federation and impersonate lab-specific GCP service accounts. No GCP service account keys are stored.
- **Plan identity:** repository-scoped contexts can impersonate plan service accounts for Terraform validation/plan.
- **Apply identity:** protected GitHub Environment subjects can impersonate apply service accounts for approved apply/destroy operations.

## Validation and handoff checks

Run static checks before review:

```sh
terraform -chdir=infra/gcp-bootstrap/shared-project fmt -check -recursive
terraform -chdir=infra/gcp-bootstrap/shared-project init -backend=false
terraform -chdir=infra/gcp-bootstrap/shared-project validate
terraform -chdir=infra/gcp-bootstrap/shared-project test

terraform -chdir=labs/07-static-site-gce/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/07-static-site-gce/infra/bootstrap init -backend=false
terraform -chdir=labs/07-static-site-gce/infra/bootstrap validate
terraform -chdir=labs/07-static-site-gce/infra/bootstrap test

terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap init -backend=false
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap validate
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap test
```

Run live checks only after local placeholder files are filled with real private values:

```sh
terraform -chdir=infra/gcp-bootstrap/shared-project plan -var-file=terraform.tfvars
terraform -chdir=labs/07-static-site-gce/infra/bootstrap init -backend-config=backend.hcl
terraform -chdir=labs/07-static-site-gce/infra/bootstrap plan
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap init -backend-config=backend.hcl
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap plan
```

CI WIF proof is a plan job, not a key download:

1. Trigger the GCP bootstrap CI workflow from a pull request or `workflow_dispatch`.
2. Confirm `google-github-actions/auth` succeeds for the lab plan service account.
3. Confirm AWS OIDC role assumption succeeds for the ECR plan role.
4. Confirm Terraform reaches `plan` with `-lock=false` and does not run apply or destroy.

## Handoff checklist

- [ ] Manual project and billing prerequisites are complete.
- [ ] Shared bootstrap applied with local ADC and local state kept private.
- [ ] Shared outputs captured for per-lab configuration.
- [ ] Lab 07 and Lab 08 backend/config examples copied to ignored local files and filled with real values.
- [ ] Per-lab bootstrap applied using the shared GCS state bucket.
- [ ] ECR canonical repositories and Artifact Registry mirrors exist.
- [ ] Plan/apply service accounts, custom roles, and WIF bindings exist.
- [ ] CI proves GitHub OIDC to AWS and GitHub WIF to GCP without long-lived keys.
- [ ] Future runtime issue implementers know which outputs to consume and which resources must survive runtime destroy.
