mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

override_data {
  target = data.aws_iam_policy_document.github_plan_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:OWNER/REPO:pull_request",
              "repo:OWNER/REPO:ref:refs/heads/main",
            ]
          }
        }
      }]
    })
  }
}

override_data {
  target = data.aws_iam_policy_document.github_image_push_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:OWNER/REPO:ref:refs/heads/main"
          }
        }
      }]
    })
  }
}

override_data {
  target = data.aws_iam_policy_document.github_apply_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:OWNER/REPO:environment:lab-06-stage"
          }
        }
      }]
    })
  }
}

override_resource {
  target          = aws_ecr_repository.service
  override_during = plan
  values = {
    arn            = "arn:aws:ecr:ap-northeast-1:123456789012:repository/devops-static-site-ecs-stage-cidr-calculator"
    repository_url = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/devops-static-site-ecs-stage-cidr-calculator"
  }
}

override_resource {
  target          = aws_iam_role.github_plan
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:role/devops-static-site-ecs-stage-github-plan"
  }
}

override_resource {
  target          = aws_iam_role.github_image_push
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:role/devops-static-site-ecs-stage-github-image-push"
  }
}

override_resource {
  target          = aws_iam_role.github_apply
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:role/devops-static-site-ecs-stage-github-apply"
  }
}

override_resource {
  target          = aws_iam_policy.github_plan
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:policy/devops-static-site-ecs-stage-github-plan"
  }
}

override_resource {
  target          = aws_iam_policy.github_image_push
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:policy/devops-static-site-ecs-stage-github-image-push"
  }
}

override_resource {
  target          = aws_iam_policy.github_apply
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:policy/devops-static-site-ecs-stage-github-apply"
  }
}

run "lab06_bootstrap_contract" {
  command = plan

  variables {
    github_repository = "OWNER/REPO"
  }

  assert {
    condition     = aws_ecr_repository.service.name == "devops-static-site-ecs-stage-cidr-calculator" && aws_ecr_repository.service.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.service.image_scanning_configuration[0].scan_on_push == true && aws_ecr_repository.service.encryption_configuration[0].encryption_type == "AES256"
    error_message = "Lab 06 bootstrap should create an immutable, scan-on-push, encrypted ECR repository using the lab naming style."
  }

  assert {
    condition     = strcontains(aws_ecr_lifecycle_policy.service.policy, "sha-") && strcontains(aws_ecr_lifecycle_policy.service.policy, "imageCountMoreThan") && strcontains(aws_ecr_lifecycle_policy.service.policy, "20") && strcontains(aws_ecr_lifecycle_policy.service.policy, "untagged")
    error_message = "Lab 06 bootstrap should own image history by retaining recent SHA images and expiring untagged images."
  }

  assert {
    condition     = aws_iam_role.github_plan.name == "devops-static-site-ecs-stage-github-plan" && aws_iam_role.github_image_push.name == "devops-static-site-ecs-stage-github-image-push" && aws_iam_role.github_apply.name == "devops-static-site-ecs-stage-github-apply"
    error_message = "Lab 06 bootstrap should create separate GitHub OIDC roles for plan, image push, and approved apply/destroy."
  }

  assert {
    condition     = aws_iam_role.github_plan.permissions_boundary == "arn:aws:iam::123456789012:policy/lab-gitops-oidc-apply-permissions-boundary" && aws_iam_role.github_image_push.permissions_boundary == aws_iam_role.github_plan.permissions_boundary && aws_iam_role.github_apply.permissions_boundary == aws_iam_role.github_plan.permissions_boundary
    error_message = "All Lab 06 GitHub OIDC roles should use the lab permissions boundary."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "token.actions.githubusercontent.com:aud") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "sts.amazonaws.com") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "repo:OWNER/REPO:pull_request") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "repo:OWNER/REPO:ref:refs/heads/main")
    error_message = "Plan role trust must stay scoped to the GitHub OIDC audience and PR/main subjects."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.github_image_push_assume_role.json, "repo:OWNER/REPO:ref:refs/heads/main") && strcontains(data.aws_iam_policy_document.github_apply_assume_role.json, "repo:OWNER/REPO:environment:lab-06-stage") && aws_iam_role.github_apply.assume_role_policy == data.aws_iam_policy_document.github_apply_assume_role.json
    error_message = "Image push trust should stay on main and apply trust should stay scoped to the protected Lab 06 environment."
  }

  assert {
    condition     = strcontains(aws_iam_policy.github_plan.policy, "ecs:Describe*") && strcontains(aws_iam_policy.github_plan.policy, "logs:DescribeLogGroups") && strcontains(aws_iam_policy.github_plan.policy, "application-autoscaling:Describe*") && strcontains(aws_iam_policy.github_apply.policy, "ecs:CreateExpressGatewayService") && strcontains(aws_iam_policy.github_apply.policy, "logs:PutRetentionPolicy") && strcontains(aws_iam_policy.github_apply.policy, "application-autoscaling:RegisterScalableTarget") && strcontains(aws_iam_policy.github_apply.policy, "iam:PassRole") && strcontains(aws_iam_policy.github_image_push.policy, "ecr:PutImage")
    error_message = "Bootstrap IAM policies should grant the CI plan, ECS Express runtime apply, CloudWatch Logs, autoscaling, runtime IAM, and image push permissions needed by the lab contract."
  }

  assert {
    condition     = output.ecr_repository_name == "devops-static-site-ecs-stage-cidr-calculator" && output.ecr_repository_url == aws_ecr_repository.service.repository_url && output.github_plan_role_arn == aws_iam_role.github_plan.arn && output.github_image_push_role_arn == aws_iam_role.github_image_push.arn && output.github_apply_role_arn == aws_iam_role.github_apply.arn
    error_message = "Bootstrap outputs should expose the ECR repository and GitHub role ARNs needed by CI and deploy workflows."
  }
}

run "lab06_bootstrap_state_scope_contract" {
  command = plan

  variables {
    github_repository = "OWNER/REPO"
  }

  assert {
    condition     = strcontains(aws_iam_policy.github_plan.policy, "infra/stage/terraform.tfstate")
    error_message = "Plan role S3 policy must reference the canonical runtime stage state object."
  }

  assert {
    condition     = strcontains(aws_iam_policy.github_plan.policy, "infra/stage/terraform.tfstate.tflock")
    error_message = "Plan role S3 policy must reference the runtime stage lock object so plans can acquire and release locks."
  }

  assert {
    condition     = !strcontains(aws_iam_policy.github_plan.policy, "infra/bootstrap")
    error_message = "Plan role must not reach bootstrap state; scope S3 access to runtime stage state only."
  }

  assert {
    condition = alltrue([
      for r in flatten([
        for s in jsondecode(aws_iam_policy.github_plan.policy).Statement :
        tolist(s.Resource)
        if contains(tolist(s.Action), "s3:PutObject") || contains(tolist(s.Action), "s3:DeleteObject")
      ]) : endswith(r, ".tflock")
    ])
    error_message = "Plan role may only mutate the .tflock lock object, never the stage state object itself."
  }

  assert {
    condition     = strcontains(aws_iam_policy.github_apply.policy, "infra/stage/terraform.tfstate") && strcontains(aws_iam_policy.github_apply.policy, "infra/stage/terraform.tfstate.tflock")
    error_message = "Apply role S3 policy must be scoped to the runtime stage state object and its lock."
  }

  assert {
    condition     = !strcontains(aws_iam_policy.github_apply.policy, "infra/bootstrap")
    error_message = "Apply role must not reach bootstrap state; scope S3 access to runtime stage state only."
  }

  assert {
    condition     = strcontains(aws_iam_policy.github_plan.policy, "infra/stage/") && strcontains(aws_iam_policy.github_apply.policy, "infra/stage/")
    error_message = "S3 ListBucket prefix conditions must be scoped to the runtime stage prefix."
  }
}
