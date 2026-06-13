# Shared infrastructure

## `gcp-bootstrap/shared-project/`

Bootstraps the shared foundation inside an already-created, billing-linked GCP project for future GCE and Cloud Run labs.

This root intentionally uses local Terraform state as the first-run exception because it creates the shared GCS state bucket. Later GCP bootstrap and runtime roots should use that bucket with GCS remote state.

It manages the minimal project APIs, the versioned state bucket, a monthly budget guardrail, a shared GitHub Workload Identity Federation pool/provider, and common labels. Copy `terraform.tfvars.example` to the ignored `terraform.tfvars` for account-specific values.

## `account-bootstrap/github-oidc-provider/`

Creates the account-level IAM OpenID Connect provider for GitHub Actions:

```text
https://token.actions.githubusercontent.com
```

This is shared bootstrap infrastructure, not per-lab runtime infrastructure. It lets GitHub Actions exchange OIDC tokens for AWS STS credentials with `AssumeRoleWithWebIdentity`, so lab-specific CI/CD roles can be assumed without storing long-lived AWS access keys in GitHub.

Create this provider once per AWS account before applying lab bootstrap stacks that define GitHub-assumable IAM roles.

The provider can be reused by any lab in the same AWS account that needs GitHub Actions OIDC in its CI/CD pipeline. Do not create a separate OIDC provider per lab. Instead, each lab should define its own IAM roles and policies that trust this shared provider.

For each new lab, add:

- An IAM role trusted by `token.actions.githubusercontent.com`.
- Trust policy conditions scoped to the intended GitHub context, such as:
  - PR checks: `repo:OWNER/REPO:pull_request`
  - protected environment deploys: `repo:OWNER/REPO:environment:ENV_NAME`
  - branch deploys: `repo:OWNER/REPO:ref:refs/heads/main`
- Least-privilege permissions for that lab's CI/CD tasks.
- Workflow permissions that allow OIDC token issuance:

```yaml
permissions:
  id-token: write
  contents: read
```

Then the workflow can assume the lab-specific role with `aws-actions/configure-aws-credentials`.
