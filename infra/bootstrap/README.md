# Shared bootstrap roots

This directory contains the shared cloud bootstrap roots that must exist before per-lab bootstrap roots and GitHub Actions live plans can work.

## Layout

- [`aws`](aws/) — AWS account bootstrap. Creates the shared GitHub OIDC provider. Uses remote S3 state configured by `backend.hcl` because the AWS state bucket is an external sandbox prerequisite.
- [`gcp`](gcp/) — GCP shared project bootstrap. Creates project APIs, the shared GCS state bucket, budget guardrail, and GitHub Workload Identity Federation pool/provider. Uses local state for first apply because it creates the GCS state bucket used by later roots.

## Configuration pattern

Both roots use `terraform.tfvars.example` for normal Terraform input variables:

```sh
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```

Only the AWS root also has `backend.hcl.example`:

```sh
cd infra/bootstrap/aws
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl
terraform init -backend-config=backend.hcl
```

The GCP root intentionally has no backend file for first apply:

```sh
cd infra/bootstrap/gcp
terraform init
```

`backend.hcl`, `terraform.tfvars`, and Terraform state files are account/project-specific and must remain untracked.

## Bootstrap order

1. Ensure AWS sandbox prerequisites exist: S3 state bucket and permissions boundaries.
2. Apply [`aws`](aws/) to create the shared GitHub OIDC provider.
3. Apply AWS per-lab bootstrap roots for Labs 05 and 06.
4. Ensure the GCP project and billing link exist.
5. Apply [`gcp`](gcp/) to create the shared project foundation.
6. Apply GCP per-lab bootstrap roots for Labs 07 and 08 using the shared GCP outputs.
7. Confirm GitHub Environments exist: `lab-05-stage`, `lab-06-stage`, `lab-07-stage`, and `lab-08-stage`.

## Runtime destroy boundary

Shared bootstrap roots are durable. Runtime deploy/destroy workflows must not initialize or destroy `infra/bootstrap/aws`, `infra/bootstrap/gcp`, or per-lab bootstrap roots. They should target only lab runtime stage roots and runtime state prefixes.
