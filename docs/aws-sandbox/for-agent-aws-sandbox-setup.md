# For agents: reusable AWS sandbox setup

Use this guide when applying the sandbox IAM pattern to a new Terraform lab project.

## Files in this directory

Policy source files:

- `inline-policy.json` — IAM Identity Center permission set inline policy for the local Terraform operator.
- `lab-devops-permissions-boundary.json` — strict boundary for workload/runtime roles created by Terraform.
- `lab-gitops-oidc-apply-permissions-boundary.json` — broader-but-guarded boundary for GitHub Actions OIDC Terraform apply roles.

Human explanation:

- `for-human-aws-sandbox-iam.md`

## Account bootstrap checklist

1. Create or choose an IAM Identity Center permission set for the Terraform operator, for example `agent`.
2. Attach `PowerUserAccess` to that permission set.
3. Add `inline-policy.json` as the permission set inline policy.
4. Do **not** attach a permissions boundary to the IAM Identity Center permission set.
5. Create these customer managed policies in each sandbox account:
   - `lab-devops-permissions-boundary`
   - `lab-gitops-oidc-apply-permissions-boundary`
6. Provision the permission set to the target AWS account.
7. Bootstrap the shared GitHub OIDC provider once per account.
8. Bootstrap each project's GitHub OIDC roles locally before expecting GitHub Actions to use them.

## Terraform naming rules

All lab IAM resources should use one of these prefixes:

```text
devops-*
lab-*
terraform-*
```

Customer managed policies should also use one of those prefixes unless they are account-bootstrap guardrails such as the two boundary policies.

## Role boundary selection

Use the runtime boundary for workload roles:

```hcl
permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-devops-permissions-boundary"
```

Use the GitOps apply boundary for GitHub OIDC Terraform apply roles:

```hcl
permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-gitops-oidc-apply-permissions-boundary"
```

Do not use the runtime boundary for a Terraform apply role that must create IAM resources; the runtime boundary denies `iam:*`.

## GitHub OIDC role trust pattern

Create the GitHub OIDC provider once per account:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = []
}
```

Restrict each role trust policy to the exact repository and branch/environment subject.

For GitHub environments:

```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:environment:dev"
  }
}
```

For pull-request plan roles:

```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:pull_request"
  }
}
```

Prefer exact `StringEquals` over wildcard `StringLike` unless a wildcard is intentionally required.

## Terraform role pattern

```hcl
data "aws_caller_identity" "current" {}

locals {
  runtime_boundary_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-devops-permissions-boundary"
  gitops_apply_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-gitops-oidc-apply-permissions-boundary"
}

resource "aws_iam_role" "ecs_task_execution" {
  name                 = "${local.name_prefix}-ecs-task-execution-role"
  permissions_boundary = local.runtime_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "github_apply" {
  name                 = "${local.name_prefix}-github-apply"
  permissions_boundary = local.gitops_apply_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:OWNER/REPO:environment:dev"
          }
        }
      }
    ]
  })
}
```

## Managed policy and PassRole rules

Allowed AWS managed policies currently include:

```text
arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices
arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
```

For additional permissions, prefer lab-prefixed customer managed policies or inline role policies.

Terraform may manage EKS cluster OIDC providers for IRSA when the provider ARN matches:

```text
arn:aws:iam::*:oidc-provider/oidc.eks.*.amazonaws.com/id/*
```

Terraform may create the EKS managed node group service-linked role and read it for EKS validation. The pathless ARN covers IAM's pre-create validation path before the service-linked role exists:

```text
arn:aws:iam::*:role/AWSServiceRoleForAmazonEKSNodegroup
arn:aws:iam::*:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup
```

Terraform may pass lab-prefixed roles only to approved services such as:

- `ec2.amazonaws.com`
- `ecs-tasks.amazonaws.com`
- `ecs.amazonaws.com`
- `lambda.amazonaws.com`
- `eks.amazonaws.com`
- `rds.amazonaws.com`

Do not pass administrator, power-user, or unprefixed roles.

## Do not manage shared boundaries from lab Terraform

Lab Terraform must not create, update, delete, tag, or version these policies:

```text
lab-devops-permissions-boundary
lab-gitops-oidc-apply-permissions-boundary
```

Treat them as pre-existing account bootstrap infrastructure. Reference them by ARN only.

## Validation commands

Validate JSON files before uploading policies:

```sh
jq empty inline-policy.json \
  lab-devops-permissions-boundary.json \
  lab-gitops-oidc-apply-permissions-boundary.json
```

After provisioning, test:

- creating a lab role with an approved boundary succeeds
- creating a lab role without a boundary fails
- passing a lab role to an approved service succeeds
- passing an admin or unprefixed role fails
- GitHub OIDC role cannot call `sts:AssumeRole`
- runtime roles cannot call IAM mutation APIs

## Quick project checklist

Before running `terraform apply` or `terragrunt apply`, confirm:

- [ ] All IAM role names begin with `devops-`, `lab-`, or `terraform-`.
- [ ] Every `aws_iam_role` has an approved `permissions_boundary`.
- [ ] Workload/runtime roles use `lab-devops-permissions-boundary`.
- [ ] GitHub OIDC Terraform apply roles use `lab-gitops-oidc-apply-permissions-boundary`.
- [ ] No Terraform code modifies the shared boundary policies.
- [ ] GitHub OIDC provider is created once in shared/account bootstrap infrastructure, not once per environment.
- [ ] `iam:PassRole` targets only lab-created roles.
- [ ] Managed policy attachments are either approved AWS managed policies or lab-prefixed customer managed policies.
- [ ] Runtime roles receive only the permissions they need.
- [ ] The IAM Identity Center `agent` permission set has no permissions boundary attached.

## SCPs

No SCP is required for this sandbox pattern. Add SCPs later only for account- or OU-wide controls that should apply beyond this lab IAM design.
