# AWS account GitHub OIDC provider bootstrap

This Terraform root creates the account-level IAM OpenID Connect (OIDC) provider for GitHub Actions so lab CI/CD roles can be assumed with short-lived credentials instead of long-lived AWS access keys. It is shared bootstrap infrastructure for the whole AWS account, not per-lab runtime infrastructure.

Create this provider once per AWS account, before applying any lab bootstrap root that defines GitHub-assumable IAM roles.

## Purpose

This root manages exactly one durable resource:

- `aws_iam_openid_connect_provider.github` for the issuer `https://token.actions.githubusercontent.com` with client ID `sts.amazonaws.com`.

That provider lets GitHub Actions exchange OIDC tokens for AWS STS credentials via `AssumeRoleWithWebIdentity`. Every lab that needs GitHub Actions OIDC in its CI/CD pipeline trusts this shared provider. Do not create a separate OIDC provider per lab; each lab defines its own IAM roles and trust policies that reference this provider instead.

## Prerequisites

The following AWS account prerequisites are external to this root and are managed/documented as sandbox prerequisites, not by this Terraform:

- An S3 Terraform state bucket that this root (and the lab roots) use for remote state. Its name is account-specific and goes in the ignored local `backend.hcl`.
- The `lab-devops-permissions-boundary` permissions boundary used by lab IAM roles.
- The `lab-gitops-oidc-apply-permissions-boundary` permissions boundary used by CI apply roles.

See [`docs/aws-sandbox/`](../../../docs/aws-sandbox/) for the sandbox IAM setup, the inline policy, and the permissions-boundary definitions.

The human bootstrap operator also needs local AWS credentials with enough IAM access to create and read the account OIDC provider.

## Configure backend and variables

Copy the backend example to the ignored local file and fill in your account-specific state bucket and region:

```sh
cd infra/account-bootstrap/github-oidc-provider
cp backend.hcl.example backend.hcl
$EDITOR backend.hcl
```

`backend.hcl` is ignored by Git because it contains real account identifiers. Commit only `backend.hcl.example` with placeholder values.

This root exposes two optional variables and has sensible defaults, so no `tfvars` file is required for a standard apply:

- `aws_region` (default `ap-northeast-1`) — region used for provider operations. IAM resources are global.
- `tags` (default project/environment/managed-by map) — tags applied to the OIDC provider. Note the resource ignores tag drift because GitHub/AWS managed tag values can change out of band.

## Validate and apply

Static checks (backend disabled, as CI runs them):

```sh
terraform -chdir=infra/account-bootstrap/github-oidc-provider fmt -check -recursive
terraform -chdir=infra/account-bootstrap/github-oidc-provider init -backend=false
terraform -chdir=infra/account-bootstrap/github-oidc-provider validate
```

Local apply with the operator's real backend:

```sh
cd infra/account-bootstrap/github-oidc-provider
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output
```

## Durable resources

The OIDC provider created here is durable bootstrap infrastructure. It must survive runtime create/destroy cycles for every lab. Only an explicit, intentional bootstrap-destroy operation should consider removing it, and only after every lab that trusts it has been torn down.

## CI/CD consumers

Downstream lab bootstrap roots trust this provider by issuer and account, deriving the provider ARN locally as `arn:aws:iam::<account_id>:oidc-provider/token.actions.githubusercontent.com` (see `locals.tf` in each lab bootstrap root). They do not consume this root's state directly via `terraform_remote_state`, so applying this root first is an operator ordering step rather than a Terraform data dependency.

Consumers:

- `labs/05-static-site-ec2/infra/bootstrap` — GitHub OIDC plan, image-push, and apply roles.
- `labs/06-static-site-ecs/infra/bootstrap` — GitHub OIDC plan, image-push, and apply roles.
- `labs/07-static-site-gce/infra/bootstrap` — GitHub OIDC plan and image-push roles for the ECR canonical repository.
- `labs/08-static-site-cloud-run/infra/bootstrap` — GitHub OIDC plan, image-push, and image-pull roles for the ECR canonical repository.

Each consuming lab role trusts `token.actions.githubusercontent.com` with conditions scoped to its GitHub context (pull request, branch, or protected environment). Lab workflows must request an OIDC token:

```yaml
permissions:
  id-token: write
  contents: read
```

and then assume the lab-specific role with `aws-actions/configure-aws-credentials`.

This root's `github_oidc_provider_arn` output is operator-facing confirmation that the provider exists. It is not wired into CI workflows as a hard dependency.

## Runtime destroy boundary

Runtime teardown (lab stage `terraform destroy`) must never remove this OIDC provider, the S3 state bucket, or the permissions boundaries. Runtime destroy is scoped to disposable workload resources only. The account bootstrap state in `backend.hcl` is human/operator-managed and is intentionally not granted to any runtime CI role.
