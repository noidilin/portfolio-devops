# Dev Ops Portfolio

Hands-on practice on these tools in the lab:

- IaC with Terraform, combined with Terragrunt pattern
- Containerization with Docker
- Orchestration with Kubernetes
- GitHub Action, combined with ArgoCD
- Observability with Prometheus and Grafana

## Terragrunt Pattern

This repo is gradually adopting Terragrunt for deployable labs.

### Purpose

Terragrunt is used here to centralize shared Terraform runtime configuration:

- remote state backend on S3
- state locking with DynamoDB
- generated AWS provider configuration
- a consistent workflow across Terragrunt-managed labs

Terraform code in each lab should stay focused on infrastructure resources. Shared runtime concerns belong in `root.hcl`.

### Current Pattern

- `root.hcl`
  - defines shared `remote_state`
  - generates `backend.tf`
  - generates `provider.tf`
- each Terragrunt-managed unit contains a minimal `terragrunt.hcl`
  - includes `root.hcl`
  - inherits backend and provider settings

Example:

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}
```

### State Layout

Terragrunt stores each unit's state in the shared S3 bucket using the unit path as the state key.

Example state key:

`labs/01-single-web-server/stage/services/webserver-cluster/terraform.tfstate`

### Workflow

Run Terragrunt from a Terragrunt-managed unit directory.

First-time backend bootstrap for a new account/backend:

```bash
terragrunt init --backend-bootstrap
```

Normal day-to-day usage:

```bash
terragrunt plan
terragrunt apply
```

### Conventions

- Do not add `backend "s3"` blocks to Terraform files in Terragrunt-managed units.
- Do not duplicate `provider "aws"` blocks in Terragrunt-managed units.
- Keep shared backend/provider configuration in `root.hcl`.
- Treat S3 remote state as the source of truth for Terragrunt-managed units.
