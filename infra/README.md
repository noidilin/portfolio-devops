# Infrastructure bootstrap overview

This directory contains durable bootstrap roots that prepare cloud accounts/projects for the lab runtime roots. Bootstrap resources are intentionally separate from disposable runtime resources: apply them first as a human/bootstrap operator, keep them across normal runtime destroys, and let GitHub Actions consume their identities and outputs after they exist.

## Bootstrap model

### AWS account prerequisites and shared OIDC

AWS keeps account-specific foundations as external sandbox prerequisites documented in [`docs/aws-sandbox/`](../docs/aws-sandbox/):

- S3 Terraform state bucket.
- `lab-devops-permissions-boundary`.
- `lab-gitops-oidc-apply-permissions-boundary`.

Terraform manages only the shared GitHub OIDC provider in [`bootstrap/aws`](bootstrap/aws/). Per-lab AWS bootstrap roots derive the provider ARN and create their own durable ECR repositories plus GitHub OIDC plan/image/apply roles.

### GCP shared project bootstrap

GCP uses a shared-project bootstrap root at [`bootstrap/gcp`](bootstrap/gcp/) for foundations that are naturally project-scoped:

- Required APIs.
- Shared GCS Terraform state bucket.
- Budget guardrail.
- Shared GitHub Workload Identity Federation pool/provider.

Per-lab GCP bootstrap roots consume the shared outputs (`project_id`, `project_number`, `state_bucket_name`, `github_wif_pool_name`, and `github_wif_provider_name`) and create lab-owned Artifact Registry repositories, service accounts, custom roles, WIF impersonation bindings, and state IAM grants.

## Manual bootstrap sequence after merge/refactor

1. Ensure the AWS sandbox prerequisites in [`docs/aws-sandbox/`](../docs/aws-sandbox/) exist.
2. Apply [`bootstrap/aws`](bootstrap/aws/) with a local ignored `backend.hcl`.
3. Apply [`../labs/05-static-site-ec2/infra/bootstrap`](../labs/05-static-site-ec2/infra/bootstrap/).
4. Apply [`../labs/06-static-site-ecs/infra/bootstrap`](../labs/06-static-site-ecs/infra/bootstrap/).
5. Apply [`bootstrap/gcp`](bootstrap/gcp/) if the shared GCP project foundations are not already applied.
6. Apply [`../labs/07-static-site-gce/infra/bootstrap`](../labs/07-static-site-gce/infra/bootstrap/) using the shared GCP bootstrap outputs.
7. Apply [`../labs/08-static-site-cloud-run/infra/bootstrap`](../labs/08-static-site-cloud-run/infra/bootstrap/) using the shared GCP bootstrap outputs.
8. Confirm GitHub Environments exist and have required reviewers: `lab-05-stage`, `lab-06-stage`, `lab-07-stage`, and `lab-08-stage`.
9. Re-run PR CI/live plans. These are expected to work only after the human first-apply bootstrap identities exist.
10. After merge, use approved deploy workflows for runtime creation and approved destroy workflows for runtime teardown.

## Runtime destroy boundary

Runtime destroy workflows target only the lab runtime stage roots and their runtime state prefixes. They must not destroy account/shared bootstrap roots, ECR repositories, Artifact Registry repositories, GitHub OIDC/WIF foundations, CI service accounts/roles, permissions boundaries, budgets, or state buckets.

See [`../docs/validation/issue-51-bootstrap-docs-validation.md`](../docs/validation/issue-51-bootstrap-docs-validation.md) for the validation evidence recorded for the bootstrap alignment.
