# Bootstrap pattern alignment plan

Date: 2026-06-16

## Goal

Align the durable bootstrap code pattern across AWS runtime labs (05/06) and GCP runtime labs (07/08) so CI/CD prerequisites, trust boundaries, backend configuration, naming, labels/tags, state access, tests, and operator docs follow one predictable model.

This plan intentionally aligns root-level Terraform code without extracting shared modules. The labs should remain readable as learning examples while still reducing accidental drift.

## Scope

### In scope

- `infra/bootstrap/aws`
- `labs/05-static-site-ec2/infra/bootstrap`
- `labs/06-static-site-ecs/infra/bootstrap`
- `labs/07-static-site-gce/infra/bootstrap`
- `labs/08-static-site-cloud-run/infra/bootstrap`
- Bootstrap-related CI workflows:
  - `.github/workflows/ec2-ecs-ci.yml`
  - `.github/workflows/gcp-bootstrap-ci.yml`
  - any deploy/destroy workflow references to bootstrap outputs/role names if affected
- Lab/root README files and bootstrap runbooks
- Terraform contract tests for bootstrap roots

### Out of scope

- Extracting shared Terraform modules
- Reworking runtime module architecture
- Moving workflow constants into GitHub repository variables
- Managing AWS account-level state bucket and permissions-boundary policies with Terraform
- Destroying/recreating already-provisioned bootstrap resources for migration. Current assumption: nothing has been provisioned since the refactor, so alignment can rename resources without state migration.

## Canonical bootstrap model

### Shared/account bootstrap

AWS and GCP are intentionally not perfectly symmetrical:

- AWS account prerequisites remain external/documented sandbox prerequisites:
  - S3 Terraform state bucket
  - `lab-devops-permissions-boundary`
  - `lab-gitops-oidc-apply-permissions-boundary`
- AWS Terraform manages the shared GitHub OIDC provider only in `infra/bootstrap/aws`.
- GCP Terraform manages shared project bootstrap in `infra/bootstrap/gcp`, including:
  - GCS state bucket
  - project APIs
  - budget guardrail
  - GitHub Workload Identity Federation pool/provider

### Per-lab bootstrap role taxonomy

AWS-runtime labs 05/06 create:

- ECR repository and lifecycle policy
- GitHub OIDC plan role
- GitHub OIDC image-push role
- GitHub OIDC apply role

GCP-runtime labs 07/08 create:

- AWS canonical ECR repository and lifecycle policy
- AWS GitHub OIDC plan role
- AWS GitHub OIDC image-push role
- AWS GitHub OIDC image-pull role
- GCP Artifact Registry mirror repository and cleanup policies
- GCP plan service account
- GCP apply service account
- GCP plan/apply custom roles
- GCP WIF impersonation bindings

## Accepted decisions

1. **GCP plan WIF trust**: use explicit PR/main subjects, not repository-wide `principalSet`.
2. **AWS plan trust**: use OIDC audience plus subject only. Remove Lab 07's extra `job_workflow_ref` constraint.
3. **GCP WIF inputs**: per-lab GCP bootstrap roots accept full WIF resource names from shared bootstrap outputs.
4. **Tags/labels variables**: use `aws_tags` and `gcp_labels` in dual-cloud roots.
5. **GCP state variable**: use `gcp_state_bucket_name`.
6. **State outputs**: use `gcp_state_bucket_name` and `gcp_runtime_state_prefix`.
7. **Artifact Registry cleanup**: keep recent versions, delete old `sha-*` tagged images, and delete untagged images after one day.
8. **Bootstrap-admin custom role**: remove Lab 08's unused bootstrap-admin role.
9. **GCP service account naming**: use `devops-<runtime>-<environment>-<purpose>`, e.g. `devops-gce-stage-plan`, `devops-cloudrun-stage-apply`.
10. **Migration posture**: no state migration required because nothing has been provisioned since the refactor.
11. **AWS account-bootstrap backend config**: track `backend.hcl.example`; keep real `backend.hcl` ignored.
12. **AWS shared prerequisites**: keep state bucket and boundary policies external/documented.
13. **GCP labels**: preserve semantic hyphenated values where GCP allows them, matching AWS tag values as closely as possible.
14. **Terraform resource names**: standardize equivalent resource local names across roots.
15. **No shared modules yet**: align explicit root code first.
16. **Root READMEs**: every bootstrap root gets a small README with the same sections.
17. **Contract tests**: assert canonical cross-lab pattern to prevent future drift.
18. **CI first-run model**: human manually applies bootstrap first; after identities exist, CI live plans should pass.
19. **AWS plan state permissions**: read state, mutate only `.tflock` files.
20. **AWS state scope**: GitHub plan/apply roles are scoped to runtime stage state only, not whole lab prefix.
21. **GCP plan state permissions**: bucket-level objectViewer plus conditional objectAdmin only for lock files.
22. **GCP apply state permissions**: conditional objectAdmin only for runtime prefix.
23. **GCP plan state prefixes**: because the same GCP plan service account is used by bootstrap PR plans and runtime PR plans, allow bootstrap and runtime prefixes for read/lock.
24. **Variable validation**: add consistent validation for key name/trust variables.
25. **GCP WIF grants**: use `google_service_account_iam_member`, not authoritative `iam_binding`.
26. **Artifact Registry cleanup vars**: use `artifact_registry_*` names.
27. **ECR lifecycle vars**: keep ECR lifecycle thresholds hard-coded at lab defaults.
28. **Workflow constants**: keep non-secret cloud constants hard-coded in workflow YAML.

## Drift inventory

### Account bootstrap backend drift

Current drift:

- `infra/bootstrap/aws/backend.hcl` is tracked and contains real account state settings.
- Lab bootstrap roots use `backend.hcl.example` plus ignored local `backend.hcl`.

Target:

- Add `infra/bootstrap/aws/backend.hcl.example`.
- Remove tracked real `backend.hcl` from Git.
- Ensure `.gitignore` ignores real `backend.hcl` files consistently.

### GCP WIF trust drift

Current drift:

- Lab 07 plan WIF uses explicit `principal://.../subject/repo:...:pull_request` and `...:ref:refs/heads/main` members.
- Lab 08 plan WIF uses broad repository `principalSet://.../attribute.repository/...`.

Target:

- Lab 08 uses explicit PR/main subjects.
- Both labs use `google_service_account_iam_member` resources for each WIF member.
- Apply WIF remains protected-environment subject only.

### AWS OIDC trust drift

Current drift:

- Labs 05/06 AWS plan roles trust PR and main subjects.
- Lab 07 AWS plan role also includes `job_workflow_ref` for `gcp-bootstrap-ci.yml`.
- Lab 08 does not include that extra condition.

Target:

- All AWS plan roles use audience `sts.amazonaws.com` plus subjects:
  - `repo:${var.github_repository}:pull_request`
  - `repo:${var.github_repository}:ref:refs/heads/main`
- Image push remains `main` only.
- Apply/image-pull remains protected GitHub Environment subject only.

### GCP WIF variable drift

Current drift:

- Lab 07 accepts full `github_wif_pool_name` and `github_wif_provider_name`.
- Lab 08 accepts IDs and derives full names internally.

Target:

- Both labs accept full shared bootstrap outputs:
  - `github_wif_pool_name`
  - `github_wif_provider_name`
- Lab 08 removes `data.google_project.current` dependency if only used for WIF name derivation.

### Tags and labels drift

Current drift:

- Lab 07 uses `aws_tags` and `gcp_labels`.
- Lab 08 uses generic `tags` and `labels`.
- Lab 08 transforms some GCP label values to underscores.

Target:

- Dual-cloud roots use `aws_tags` and `gcp_labels`.
- GCP labels preserve semantic values where valid:
  - `project = var.project_name`
  - `environment = var.environment`
  - `lab = local.lab_id`
  - `managed_by = "terraform"`
  - `service = var.service_name`

### State variable and output drift

Current drift:

- Lab 07 uses `terraform_state_bucket_name` and output `runtime_state_prefix`.
- Lab 08 uses `gcp_state_bucket_name` and output `gcp_runtime_state_prefix`.

Target:

- Both GCP per-lab bootstrap roots use variable `gcp_state_bucket_name`.
- Both output:
  - `gcp_state_bucket_name`
  - `gcp_runtime_state_prefix`

### Artifact Registry cleanup drift

Current drift:

- Lab 07 deletes old `sha-*` tagged images and keeps recent versions.
- Lab 08 deletes untagged images and keeps recent versions.

Target:

Both labs define all three cleanup policies:

1. Keep recent versions, count from `var.artifact_registry_keep_count`.
2. Delete old `sha-*` tagged images older than `var.artifact_registry_delete_older_than`.
3. Delete untagged images older than `var.artifact_registry_untagged_delete_older_than`.

Canonical defaults:

- `artifact_registry_keep_count = 20`
- `artifact_registry_delete_older_than = "2592000s"`
- `artifact_registry_untagged_delete_older_than = "86400s"`

ECR lifecycle remains hard-coded:

- keep most recent 20 `sha-` tagged images
- expire untagged images after one day

### Bootstrap-admin drift

Current drift:

- Lab 08 defines `google_project_iam_custom_role.bootstrap_admin` but it is not part of the canonical runtime CI/CD identity model.
- Lab 07 does not define it.

Target:

- Remove Lab 08 bootstrap-admin custom role and local ID.
- Keep human/bootstrap operator permissions as external prerequisites documented in the runbook.

### GCP service account naming drift

Current drift:

- Lab 07 uses `devops-gce-stage-plan` / `devops-gce-stage-apply`.
- Lab 08 uses `lab-08-cloudrun-plan` / `lab-08-cloudrun-apply`.

Target:

- Lab 08 changes to:
  - `devops-cloudrun-${var.environment}-plan`
  - `devops-cloudrun-${var.environment}-apply`
- Workflow constants update to:
  - `devops-cloudrun-stage-plan@portfolio-devops-labs.iam.gserviceaccount.com`
  - `devops-cloudrun-stage-apply@portfolio-devops-labs.iam.gserviceaccount.com`

### Terraform local resource name drift

Target resource local names:

AWS and dual-cloud roots:

- `aws_ecr_repository.service`
- `aws_ecr_lifecycle_policy.service`
- `aws_iam_role.github_plan`
- `aws_iam_role.github_image_push`
- `aws_iam_role.github_apply` for AWS-runtime labs
- `aws_iam_role.github_image_pull` for GCP-runtime labs

GCP dual-cloud roots:

- `google_artifact_registry_repository.service`
- `google_service_account.plan`
- `google_service_account.apply`
- `google_project_iam_custom_role.plan`
- `google_project_iam_custom_role.apply`
- `google_project_iam_member.plan`
- `google_project_iam_member.apply`
- `google_storage_bucket_iam_member.plan_state_read`
- `google_storage_bucket_iam_member.plan_state_lock_bootstrap`
- `google_storage_bucket_iam_member.plan_state_lock_runtime`
- `google_storage_bucket_iam_member.apply_state_runtime`
- `google_service_account_iam_member.github_plan_wif_pull_request`
- `google_service_account_iam_member.github_plan_wif_main`
- `google_service_account_iam_member.github_apply_wif`

Because no post-refactor resources are provisioned, no `moved` blocks are required for resource local-name changes.

## Target state-access model

### AWS runtime CI roles

Plan role:

- `s3:GetObject` on stage state object.
- `s3:PutObject` and `s3:DeleteObject` only on stage `.tflock` object.
- `s3:ListBucket` limited to the stage state prefix.

Apply role:

- `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on the stage state object and lock file only.
- `s3:ListBucket` limited to the stage state prefix.

Canonical stage state keys:

- Lab 05: `labs/05-static-site-ec2/infra/stage/terraform.tfstate`
- Lab 06: `labs/06-static-site-ecs/infra/stage/terraform.tfstate`

Bootstrap state stays human/local managed and is not granted to runtime CI roles.

### GCP plan service accounts

Plan service accounts are used by both bootstrap PR plans and runtime PR plans after the human first apply.

Grant:

- `roles/storage.objectViewer` on the shared state bucket.
- Conditional `roles/storage.objectAdmin` only for `.tflock` objects under:
  - bootstrap prefix: `gcp/bootstrap/labs/<lab-id>/`
  - runtime prefix: `gcp/runtime/labs/<lab-id>/<environment>/`

### GCP apply service accounts

Apply service accounts are used by approved runtime deploy/destroy workflows.

Grant:

- Conditional `roles/storage.objectAdmin` only for runtime state prefix:
  - `gcp/runtime/labs/<lab-id>/<environment>/`

Do not grant apply identities broad objectAdmin over the whole shared state bucket.

## Implementation phases

### Phase 1: account-bootstrap backend alignment

1. Create `infra/bootstrap/aws/backend.hcl.example` with placeholder S3 backend settings.
2. Remove tracked `infra/bootstrap/aws/backend.hcl` from Git.
3. Confirm `.gitignore` ignores real `backend.hcl` files.
4. Add or update README for this root with:
   - purpose
   - prerequisites
   - configure
   - validate/apply
   - durable resources
   - CI outputs/consumers

### Phase 2: AWS Labs 05/06 bootstrap state-permission tightening

1. Add locals for canonical runtime stage state key and lock object.
2. Update GitHub plan role S3 policy:
   - state read only
   - `.tflock` mutation only
   - prefix-scoped list
3. Update GitHub apply role S3 policy:
   - stage state and lock only
   - prefix-scoped list
4. Add consistent variable validation:
   - `github_repository`
   - `environment`
   - `project_name`
   - `service_name`
5. Add bootstrap root READMEs if missing.
6. Update contract tests to assert:
   - ECR immutable/scan/encryption/lifecycle
   - role taxonomy
   - trust subjects
   - permissions boundary
   - state policy scope
   - outputs used by workflows

### Phase 3: Lab 07 GCP bootstrap alignment

1. Rename variable `terraform_state_bucket_name` to `gcp_state_bucket_name`.
2. Rename output `terraform_state_bucket_name` to `gcp_state_bucket_name`.
3. Rename output `runtime_state_prefix` to `gcp_runtime_state_prefix`.
4. Rename `google_artifact_registry_repository.mirror` to `.service`.
5. Remove AWS plan `job_workflow_ref` condition.
6. Ensure GCP WIF plan/apply grants use `google_service_account_iam_member` resources.
7. Split plan state lock IAM into bootstrap and runtime conditional lock grants.
8. Scope apply state access to runtime prefix only.
9. Add untagged Artifact Registry cleanup variable and policy.
10. Confirm labels preserve semantic values.
11. Update examples, README, outputs, tests, and workflows if references change.

### Phase 4: Lab 08 GCP bootstrap alignment

1. Replace WIF ID variables with full-name variables:
   - remove/stop using `github_wif_pool_id`
   - remove/stop using `github_wif_provider_id`
   - add `github_wif_pool_name`
   - add `github_wif_provider_name`
2. Change plan WIF from repo-wide principalSet to explicit PR/main subjects.
3. Rename generic variables:
   - `tags` -> `aws_tags`
   - `labels` -> `gcp_labels`
   - `artifact_cleanup_keep_count` -> `artifact_registry_keep_count`
4. Add cleanup variables:
   - `artifact_registry_delete_older_than`
   - `artifact_registry_untagged_delete_older_than`
5. Add old-`sha-*` Artifact Registry cleanup policy.
6. Preserve hyphenated GCP label values where valid.
7. Remove `bootstrap_admin` custom role and local ID.
8. Rename service accounts:
   - `devops-cloudrun-${var.environment}-plan`
   - `devops-cloudrun-${var.environment}-apply`
9. Add bucket-level objectViewer for plan state reads.
10. Split plan lock grants for bootstrap/runtime prefixes.
11. Scope apply state access to runtime prefix only.
12. Ensure output names match Lab 07:
   - `gcp_state_bucket_name`
   - `gcp_runtime_state_prefix`
   - `github_wif_provider_name` or equivalent provider output naming if needed
13. Update examples, README, tests, and workflows.

### Phase 5: CI workflow updates

1. Update `.github/workflows/gcp-bootstrap-ci.yml` for canonical variable names:
   - Lab 07: `gcp_state_bucket_name`
   - Lab 08: full WIF names, `aws_tags`/`gcp_labels` if emitted in CI tfvars
2. Update Lab 08 service account email constants:
   - `devops-cloudrun-stage-plan@portfolio-devops-labs.iam.gserviceaccount.com`
   - `devops-cloudrun-stage-apply@portfolio-devops-labs.iam.gserviceaccount.com`
3. Confirm `.github/workflows/gcp-runtime-ci.yml` uses updated Lab 08 plan service account.
4. Confirm `.github/workflows/gcp-runtime-deploy.yml` uses updated Lab 08 plan/apply service accounts.
5. Keep non-secret account/project constants hard-coded in YAML.
6. Preserve live bootstrap plans in PR, with the operational assumption that the human first applies bootstrap infra before expecting those live plans to pass.

### Phase 6: Docs alignment

For each bootstrap root README, use these sections:

1. Purpose
2. Prerequisites
3. Configure backend and variables
4. Validate and apply
5. Durable resources
6. CI/CD consumers
7. Runtime destroy boundary

Update central docs:

- `infra/README.md`
- `infra/bootstrap/README.md`
- lab READMEs where bootstrap names, outputs, or workflow identities are referenced
- `docs/validation/issue-41-code-pattern-alignment-validation.md` after validation is complete

### Phase 7: Validation

Run static validation for all bootstrap roots:

```sh
terraform -chdir=infra/bootstrap/aws fmt -check -recursive
terraform -chdir=infra/bootstrap/aws init -backend=false
terraform -chdir=infra/bootstrap/aws validate

terraform -chdir=labs/05-static-site-ec2/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/05-static-site-ec2/infra/bootstrap init -backend=false
terraform -chdir=labs/05-static-site-ec2/infra/bootstrap validate
terraform -chdir=labs/05-static-site-ec2/infra/bootstrap test

terraform -chdir=labs/06-static-site-ecs/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/06-static-site-ecs/infra/bootstrap init -backend=false
terraform -chdir=labs/06-static-site-ecs/infra/bootstrap validate
terraform -chdir=labs/06-static-site-ecs/infra/bootstrap test

terraform -chdir=labs/07-static-site-gce/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/07-static-site-gce/infra/bootstrap init -backend=false
terraform -chdir=labs/07-static-site-gce/infra/bootstrap validate
terraform -chdir=labs/07-static-site-gce/infra/bootstrap test

terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap fmt -check -recursive
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap init -backend=false
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap validate
terraform -chdir=labs/08-static-site-cloud-run/infra/bootstrap test
```

Run repository drift checks:

```sh
git ls-files '**/backend.hcl'
rg -n 'principalSet://iam.googleapis.com/.*/attribute.repository' labs/07-static-site-gce/infra/bootstrap labs/08-static-site-cloud-run/infra/bootstrap
rg -n 'job_workflow_ref' labs/05-static-site-ec2/infra/bootstrap labs/06-static-site-ecs/infra/bootstrap labs/07-static-site-gce/infra/bootstrap labs/08-static-site-cloud-run/infra/bootstrap
rg -n 'terraform_state_bucket_name|artifact_cleanup_|\blabels\b|\btags\b' labs/07-static-site-gce/infra/bootstrap labs/08-static-site-cloud-run/infra/bootstrap
```

Expected drift-check results:

- No tracked real `backend.hcl` files.
- No GCP per-lab plan WIF repository-wide principalSet.
- No AWS plan `job_workflow_ref` conditions.
- No old Lab 07 `terraform_state_bucket_name` variable/output.
- No Lab 08 `artifact_cleanup_*`, generic `tags`, or generic `labels` variables in dual-cloud bootstrap root.

## Manual bootstrap sequence after merge/refactor

1. Ensure AWS sandbox prerequisites exist.
2. Apply AWS account GitHub OIDC provider root with local `backend.hcl`.
3. Apply Lab 05 bootstrap.
4. Apply Lab 06 bootstrap.
5. Apply GCP shared project bootstrap if not already applied.
6. Apply Lab 07 bootstrap.
7. Apply Lab 08 bootstrap.
8. Confirm GitHub Environments exist:
   - `lab-05-stage`
   - `lab-06-stage`
   - `lab-07-stage`
   - `lab-08-stage`
9. Re-run PR CI/live plans.
10. After merge, use approved deploy workflows for runtime creation.

## Acceptance criteria

- Bootstrap roots use aligned variable, local, output, trust, lifecycle, and state-access patterns.
- AWS account-bootstrap real backend config is no longer tracked.
- GCP Labs 07/08 use explicit WIF PR/main plan subjects and protected-environment apply subjects.
- AWS plan roles do not use workflow-file-specific trust conditions.
- Plan identities cannot mutate Terraform state except lock files.
- Apply identities are scoped to runtime state, not bootstrap or whole buckets/prefixes.
- Lab 08 no longer creates an unused bootstrap-admin role.
- Lab 08 service account names follow `devops-<runtime>-<env>-<purpose>`.
- Contract tests encode the canonical pattern.
- READMEs and runbooks document first-run bootstrap order and durable-resource boundaries.
- Static validation and Terraform contract tests pass for all bootstrap roots.
