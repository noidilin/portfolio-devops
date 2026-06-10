# For humans: AWS sandbox IAM model

This sandbox lets Terraform create lab infrastructure while reducing IAM privilege-escalation risk.

## Current IAM Identity Center setup

AWS account: `549475122024`

IAM Identity Center instance:

- Name: `noidilin`
- Instance ARN: `arn:aws:sso:::instance/ssoins-775814bfd513b441`

Permission set:

- Name: `agent`
- Session duration: `PT4H`
- Attached AWS managed policy: `arn:aws:iam::aws:policy/PowerUserAccess`
- Inline policy: `inline-policy.json`
- Permissions boundary on permission set: **none**

Important: do **not** attach `lab-devops-permissions-boundary` or `lab-gitops-oidc-apply-permissions-boundary` to the IAM Identity Center `agent` permission set. Those boundaries are for roles that Terraform creates, not for the local human/agent Terraform operator.

## Permission resolution mental model

There are three relevant contexts.

### 1. Local Terraform execution

When you run Terraform locally after `aws sso login`, Terraform uses the IAM role provisioned by IAM Identity Center for the `agent` permission set, for example:

```text
arn:aws:iam::<account-id>:role/aws-reserved/sso.amazonaws.com/<region>/AWSReservedSSO_agent_...
```

Effective permissions are:

```text
PowerUserAccess
+ inline-policy.json
- any explicit deny
```

The `inline-policy.json` file is the **creation-time guardrail**. It allows scoped IAM management for lab prefixes, requires approved permissions boundaries on created roles, limits `iam:PassRole`, and blocks tampering with shared boundary policies.

### 2. Terraform-created workload/runtime role

Examples:

- ECS task execution role
- ECS task role
- Lambda execution role
- EC2 instance profile role

Effective permissions are:

```text
role identity policy allows
AND permissions boundary allows
AND no explicit deny applies
```

Use `lab-devops-permissions-boundary` for workload/runtime roles. It allows normal runtime AWS actions but denies IAM mutation, Organizations mutation, Account mutation, and `sts:AssumeRole` role chaining.

### 3. Terraform-created GitHub OIDC role

GitHub Actions roles are assumed by GitHub workflows through OIDC.

They have:

```text
trust policy
  controls which GitHub repo/environment/ref may call sts:AssumeRoleWithWebIdentity

attached identity policy
  grants project-specific Terraform/deploy actions

permissions boundary
  caps what the workflow can ever do
```

Use `lab-gitops-oidc-apply-permissions-boundary` for GitHub OIDC Terraform apply roles. It does **not** deny all `iam:*`, because Terraform apply may need to create and pass project roles. Instead, it denies common escalation paths such as role chaining, unapproved boundaries, broad `iam:PassRole`, boundary tampering, user/group mutation, and policy mutation outside lab prefixes.

## Boundary policies

### Runtime boundary

Customer managed policy:

```text
arn:aws:iam::549475122024:policy/lab-devops-permissions-boundary
```

Source file:

```text
lab-devops-permissions-boundary.json
```

Purpose:

- Allow normal workload/runtime AWS actions.
- Deny IAM, Organizations, Account mutation, and `sts:AssumeRole` role chaining.

### GitOps Terraform apply boundary

Customer managed policy:

```text
arn:aws:iam::549475122024:policy/lab-gitops-oidc-apply-permissions-boundary
```

Source file:

```text
lab-gitops-oidc-apply-permissions-boundary.json
```

Purpose:

- Cap GitHub Actions OIDC Terraform apply roles.
- Permit scoped IAM creation needed by project Terraform.
- Deny common privilege-escalation paths.

## Inline policy behavior

Source file:

```text
inline-policy.json
```

The `agent` permission set inline policy allows scoped IAM management only for these prefixes:

```text
devops-*
lab-*
terraform-*
```

It also allows tightly scoped bootstrap management for the GitHub Actions OIDC provider:

```text
arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com
```

It enforces:

1. Terraform may create lab roles only with an approved boundary: `lab-devops-permissions-boundary` or `lab-gitops-oidc-apply-permissions-boundary`.
2. Terraform may not remove role permissions boundaries.
3. Terraform may not modify the boundary policies themselves.
4. Terraform may attach only approved managed policies to lab roles.
5. `iam:PassRole` is limited to lab-prefixed roles and approved AWS services.
6. Required service-linked roles may be created for approved services.
7. GitHub OIDC provider management is limited to `token.actions.githubusercontent.com`.

## Bootstrap note

GitHub cannot assume an OIDC role before that role exists. Bootstrap order:

1. Log in locally with IAM Identity Center.
2. Create/update the shared GitHub OIDC provider once per account.
3. Create/update the project GitHub OIDC plan/apply roles.
4. Let GitHub Actions use those roles for normal project plans/applies.

Avoid having a GitHub workflow manage the role it is currently using during routine project deployment.
