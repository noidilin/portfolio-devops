override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
  }
}

override_resource {
  target          = aws_ecr_repository.service
  override_during = plan
  values = {
    arn            = "arn:aws:ecr:ap-northeast-1:123456789012:repository/devops-static-site-ec2-stage-cidr-calculator"
    repository_url = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/devops-static-site-ec2-stage-cidr-calculator"
  }
}

override_resource {
  target          = aws_iam_role.github_plan
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:role/devops-static-site-ec2-stage-github-plan"
  }
}

override_resource {
  target          = aws_iam_role.github_image_push
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:role/devops-static-site-ec2-stage-github-image-push"
  }
}

override_resource {
  target          = aws_iam_role.github_apply
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:role/devops-static-site-ec2-stage-github-apply"
  }
}

override_resource {
  target          = aws_iam_policy.github_plan
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:policy/devops-static-site-ec2-stage-github-plan"
  }
}

override_resource {
  target          = aws_iam_policy.github_image_push
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:policy/devops-static-site-ec2-stage-github-image-push"
  }
}

override_resource {
  target          = aws_iam_policy.github_apply
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:policy/devops-static-site-ec2-stage-github-apply"
  }
}

run "lab05_bootstrap_contract" {
  command = plan

  variables {
    github_repository = "OWNER/REPO"
  }

  assert {
    condition     = aws_ecr_repository.service.name == "devops-static-site-ec2-stage-cidr-calculator" && aws_ecr_repository.service.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.service.image_scanning_configuration[0].scan_on_push == true && aws_ecr_repository.service.encryption_configuration[0].encryption_type == "AES256"
    error_message = "Lab 05 bootstrap should create an immutable, scan-on-push, encrypted ECR repository using the lab naming style."
  }

  assert {
    condition     = strcontains(aws_ecr_lifecycle_policy.service.policy, "sha-") && strcontains(aws_ecr_lifecycle_policy.service.policy, "imageCountMoreThan") && strcontains(aws_ecr_lifecycle_policy.service.policy, "20") && strcontains(aws_ecr_lifecycle_policy.service.policy, "untagged")
    error_message = "Lab 05 bootstrap should own image history by retaining recent SHA images and expiring untagged images."
  }

  assert {
    condition     = aws_iam_role.github_plan.name == "devops-static-site-ec2-stage-github-plan" && aws_iam_role.github_image_push.name == "devops-static-site-ec2-stage-github-image-push" && aws_iam_role.github_apply.name == "devops-static-site-ec2-stage-github-apply"
    error_message = "Lab 05 bootstrap should create separate GitHub OIDC roles for plan, image push, and approved apply/destroy."
  }

  assert {
    condition     = aws_iam_role.github_plan.permissions_boundary == "arn:aws:iam::123456789012:policy/lab-gitops-oidc-apply-permissions-boundary" && aws_iam_role.github_image_push.permissions_boundary == aws_iam_role.github_plan.permissions_boundary && aws_iam_role.github_apply.permissions_boundary == aws_iam_role.github_plan.permissions_boundary
    error_message = "All Lab 05 GitHub OIDC roles should use the lab permissions boundary."
  }

  assert {
    condition     = strcontains(aws_iam_role.github_plan.assume_role_policy, "token.actions.githubusercontent.com:aud") && strcontains(aws_iam_role.github_plan.assume_role_policy, "sts.amazonaws.com") && strcontains(aws_iam_role.github_plan.assume_role_policy, "repo:OWNER/REPO:pull_request") && strcontains(aws_iam_role.github_plan.assume_role_policy, "repo:OWNER/REPO:ref:refs/heads/main")
    error_message = "Plan role trust must stay scoped to the GitHub OIDC audience and PR/main subjects."
  }

  assert {
    condition     = strcontains(aws_iam_role.github_image_push.assume_role_policy, "repo:OWNER/REPO:ref:refs/heads/main") && strcontains(aws_iam_role.github_apply.assume_role_policy, "repo:OWNER/REPO:environment:lab-05-stage") && aws_iam_role.github_apply.assume_role_policy == data.aws_iam_policy_document.github_apply_assume_role.json
    error_message = "Image push trust should stay on main and apply trust should stay scoped to the protected Lab 05 environment."
  }

  assert {
    condition     = strcontains(aws_iam_policy.github_plan.policy, "ecr:DescribeRepositories") && strcontains(aws_iam_policy.github_plan.policy, "ec2:Describe*") && strcontains(aws_iam_policy.github_apply.policy, "ec2:RunInstances") && strcontains(aws_iam_policy.github_apply.policy, "iam:PassRole") && strcontains(aws_iam_policy.github_image_push.policy, "ecr:PutImage")
    error_message = "Bootstrap IAM policies should grant the CI plan, runtime apply, and image push permissions needed by the lab contract."
  }

  assert {
    condition     = output.ecr_repository_name == "devops-static-site-ec2-stage-cidr-calculator" && output.github_plan_role_arn == aws_iam_role.github_plan.arn && output.github_image_push_role_arn == aws_iam_role.github_image_push.arn && output.github_apply_role_arn == aws_iam_role.github_apply.arn
    error_message = "Bootstrap outputs should expose the ECR repository and GitHub role ARNs needed by CI and deploy workflows."
  }
}

run "lab05_bootstrap_state_scope_contract" {
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
    condition = length(flatten([
      for s in jsondecode(aws_iam_policy.github_plan.policy).Statement :
      try(tolist(s.Resource), [s.Resource])
      if contains(try(tolist(s.Action), [s.Action]), "s3:PutObject") || contains(try(tolist(s.Action), [s.Action]), "s3:DeleteObject")
      ])) > 0 && alltrue([
      for r in flatten([
        for s in jsondecode(aws_iam_policy.github_plan.policy).Statement :
        try(tolist(s.Resource), [s.Resource])
        if contains(try(tolist(s.Action), [s.Action]), "s3:PutObject") || contains(try(tolist(s.Action), [s.Action]), "s3:DeleteObject")
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
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.github_plan.policy).Statement :
      try(s.Condition.StringLike["s3:prefix"], []) == ["labs/05-static-site-ec2/infra/stage/*"]
      if s.Sid == "AllowTerraformStateList"
      ]) && length([
      for s in jsondecode(aws_iam_policy.github_plan.policy).Statement : s
      if s.Sid == "AllowTerraformStateList"
      ]) == 1 && alltrue([
      for s in jsondecode(aws_iam_policy.github_apply.policy).Statement :
      try(s.Condition.StringLike["s3:prefix"], []) == ["labs/05-static-site-ec2/infra/stage/*"]
      if s.Sid == "AllowTerraformStateList"
      ]) && length([
      for s in jsondecode(aws_iam_policy.github_apply.policy).Statement : s
      if s.Sid == "AllowTerraformStateList"
    ]) == 1
    error_message = "S3 ListBucket prefix conditions must be scoped to the runtime stage prefix."
  }
}
