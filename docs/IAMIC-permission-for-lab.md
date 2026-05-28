# AWS Policy Rule for Labs

This repo is operated from an IAM Identity Center permission set named `agent`.
The goal is to let Terraform build lab infrastructure while preventing privilege escalation through IAM role creation or `iam:PassRole`.

## Current IAM Identity Center setup

AWS account: `549475122024`

IAM Identity Center instance:

- Name: `noidilin`
- Instance ARN: `arn:aws:sso:::instance/ssoins-775814bfd513b441`

Permission set:

- Name: `agent`
- Session duration: `PT4H`
- Attached AWS managed policy: `arn:aws:iam::aws:policy/PowerUserAccess`
- Inline policy: scoped IAM policy from `inline-policy.json`
- Permissions boundary on permission set: **none**

Important: do **not** attach `lab-devops-permissions-boundary` to the Identity Center `agent` permission set. That boundary is for roles created by the lab, not for the human/agent operator role. If attached to the permission set, it denies `iam:*` and prevents Terraform from creating or passing scoped lab roles.

Provisioned SSO role currently observed:

```text
arn:aws:iam::549475122024:role/aws-reserved/sso.amazonaws.com/ap-northeast-1/AWSReservedSSO_agent_8136a3cfe3394285
```

This provisioned role should have no permissions boundary.

## Boundary policy

Customer managed policy:

```text
arn:aws:iam::549475122024:policy/lab-devops-permissions-boundary
```

Source file:

```text
lab-devops-permissions-boundary.json
```

Purpose:

- Allow normal runtime AWS actions.
- Explicitly deny IAM, Organizations, and Account mutation from roles created by lab Terraform.

This prevents a lab-created runtime role from becoming an IAM administrator.

## Inline policy behavior

Source file:

```text
inline-policy.json
```

The `agent` permission set inline policy allows scoped IAM management only for these name prefixes:

- `devops-*`
- `lab-*`
- `terraform-*`

It enforces these rules:

1. Terraform may create lab roles only if they include the `lab-devops-permissions-boundary` permissions boundary.
2. Terraform may not remove role permissions boundaries.
3. Terraform may not modify the boundary policy itself.
4. Terraform may attach only approved managed policies to lab roles.
5. `iam:PassRole` is limited to lab-prefixed roles and approved AWS services.
6. Required service-linked roles may be created for services such as ECS, ELB, Auto Scaling, RDS, and EKS.

Verified behavior after removing the boundary from the permission set:

- `iam:CreateRole` for `devops-*` with boundary: allowed
- `iam:PassRole` for `devops-*` to ECS tasks: allowed
- `iam:CreateRole` for `devops-*` without boundary: explicit deny
- `iam:PassRole` to non-lab/admin role: implicit deny

## Terraform pattern to follow

### 1. Name IAM resources with approved prefixes

All Terraform-managed IAM resources for labs must use one of:

```text
devops-*
lab-*
terraform-*
```

Preferred pattern:

```hcl
locals {
  name_prefix = "devops-${var.project}-${var.environment}"
}
```

Example role name:

```hcl
name = "${local.name_prefix}-ecs-task-execution-role"
```

Avoid unprefixed names such as:

```hcl
name = "ecs-task-execution-role" # wrong
```

### 2. Always attach the lab boundary to created roles

Every `aws_iam_role` created by Terraform must set `permissions_boundary`.

```hcl
data "aws_caller_identity" "current" {}

locals {
  lab_permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-devops-permissions-boundary"
}

resource "aws_iam_role" "ecs_task_execution" {
  name                 = "${local.name_prefix}-ecs-task-execution-role"
  permissions_boundary = local.lab_permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
```

Do not create roles without the boundary. The `agent` policy should deny them.

### 3. Use AWS managed policies only when approved

Allowed AWS managed policies currently include:

```text
arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

Example:

```hcl
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

For additional permissions, prefer a lab-prefixed customer managed policy or inline role policy.

### 4. Customer managed policies must use approved prefixes

```hcl
resource "aws_iam_policy" "app_runtime" {
  name = "${local.name_prefix}-app-runtime-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}
```

The policy name must begin with `devops-`, `lab-`, or `terraform-`.

### 5. Pass only lab roles to approved services

Terraform may pass lab-prefixed roles to approved services such as:

- `ec2.amazonaws.com`
- `ecs-tasks.amazonaws.com`
- `ecs.amazonaws.com`
- `lambda.amazonaws.com`
- `eks.amazonaws.com`
- `rds.amazonaws.com`

For ECS tasks, use the lab-created execution/task roles directly:

```hcl
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([])
}
```

Do not pass administrator, power-user, or unprefixed roles.

### 6. Do not manage the boundary from lab Terraform

Lab Terraform must not create, update, delete, tag, or version this policy:

```text
lab-devops-permissions-boundary
```

Treat it as pre-existing account bootstrap infrastructure. Reference it by ARN only.

### 7. Keep service-linked role usage explicit

If a service-linked role is needed, let Terraform or AWS create only the approved service-linked roles covered by the inline policy. Do not create arbitrary IAM roles as substitutes for service-linked roles.

## Quick checklist for new Terraform labs

Before running `terraform apply` or `terragrunt apply`, confirm:

- [ ] All IAM role names begin with `devops-`, `lab-`, or `terraform-`.
- [ ] Every `aws_iam_role` has `permissions_boundary = local.lab_permissions_boundary_arn`.
- [ ] No Terraform code modifies `lab-devops-permissions-boundary`.
- [ ] `iam:PassRole` targets only lab-created roles.
- [ ] Managed policy attachments are either approved AWS managed policies or lab-prefixed customer managed policies.
- [ ] Runtime roles receive only the permissions they need.
- [ ] The Identity Center `agent` permission set has no permissions boundary attached.
