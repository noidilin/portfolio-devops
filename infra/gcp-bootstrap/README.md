# GCP bootstrap

GCP bootstrap is split into a shared project foundation and per-lab bootstrap roots. The shared root in [`shared-project`](shared-project/) is applied first by a human/bootstrap operator; Labs 07 and 08 then consume its outputs in their own bootstrap roots.

## Shared-project bootstrap model

[`shared-project`](shared-project/) owns project-wide durable foundations:

- Required GCP APIs for the GCE and Cloud Run static-site labs.
- A versioned, protected GCS Terraform state bucket.
- A budget guardrail for the billing-linked project.
- A GitHub Workload Identity Federation pool/provider scoped to this repository.

The shared root intentionally does not create per-lab service accounts, Artifact Registry repositories, runtime resources, or GitHub Environment reviewer settings.

## Per-lab relationship

Per-lab bootstrap roots consume the shared outputs:

- `project_id`
- `project_number`
- `state_bucket_name` (passed to per-lab roots as `gcp_state_bucket_name`)
- `github_wif_pool_name`
- `github_wif_provider_name`

Labs 07 and 08 then create durable lab-specific CI/CD resources: Artifact Registry mirrors, plan/apply service accounts, custom roles, explicit PR/main/protected-environment WIF impersonation members, state IAM grants, plus AWS ECR/image roles for the canonical image source.

## Runtime destroy boundary

Approved GCP runtime destroy workflows initialize only the lab runtime stage roots and runtime state prefixes:

- `gcp/runtime/labs/07-static-site-gce/stage/`
- `gcp/runtime/labs/08-static-site-cloud-run/stage/`

They must not initialize or destroy `shared-project` or any per-lab bootstrap root. Shared state buckets, WIF foundations, budgets, Artifact Registry repositories, CI service accounts, and ECR image history remain durable bootstrap resources.
