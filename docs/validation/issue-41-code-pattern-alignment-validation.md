# Issue 41 code-pattern alignment validation

Date: 2026-06-15

This report records the final repository-level validation pass for Labs 05 through 08 static-site code-pattern alignment.

## Terraform validation

For each aligned Terraform root, the following local checks were run:

```sh
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
```

| Lab root | Result |
| --- | --- |
| `labs/05-static-site-ec2/infra/bootstrap` | Passed format, backendless init, validate, and `terraform test` (`lab05_bootstrap_contract`) |
| `labs/05-static-site-ec2/infra/stage` | Passed format, backendless init, validate, and `terraform test` (`lab05_ec2_runtime_contract`) |
| `labs/06-static-site-ecs/infra/bootstrap` | Passed format, backendless init, validate, and `terraform test` (`lab06_bootstrap_contract`) |
| `labs/06-static-site-ecs/infra/stage` | Passed format, backendless init, validate, and `terraform test` (`lab06_ecs_runtime_contract`) |
| `labs/07-static-site-gce/infra/stage` | Passed format, backendless init, validate, and `terraform test` (`gce_runtime_contract`) |
| `labs/08-static-site-cloud-run/infra/stage` | Passed format, backendless init, validate, and `terraform test` (`cloud_run_runtime_contract`) |

No cloud apply or destroy checks were run locally. The closest local check was backendless Terraform initialization, static validation, and mocked/local contract tests for each root. Live mutation remains protected by the repository GitHub Actions workflows and GitHub Environment approvals.

## Repository text checks

The following repository checks were run:

```sh
git ls-files 'labs/05-static-site-ec2/**/backend.hcl' 'labs/06-static-site-ecs/**/backend.hcl'
rg -n -i '<legacy term>' docs labs .github
rg -n 'terraform test' labs/05-static-site-ec2 labs/06-static-site-ecs labs/07-static-site-gce labs/08-static-site-cloud-run \
  .github/workflows/ec2-ecs-ci.yml .github/workflows/ec2-ecs-deploy.yml \
  .github/workflows/gcp-runtime-ci.yml .github/workflows/gcp-gce-deploy.yml \
  .github/workflows/gcp-cloud-run-deploy.yml
```

Results:

- No tracked Lab 05 or Lab 06 `backend.hcl` files were found.
- No stale legacy project-name references were found under `docs`, `labs`, or `.github`.
- `terraform test` coverage is referenced by the aligned lab READMEs and relevant AWS/GCP CI or deploy workflows.
