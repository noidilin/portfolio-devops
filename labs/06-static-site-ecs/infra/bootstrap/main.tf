resource "aws_ecr_repository" "service" {
  name                 = local.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "service" {
  repository = aws_ecr_repository.service.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the most recent 20 SHA-tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after one day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_iam_role" "github_plan" {
  name                 = "${local.name_prefix}-github-plan"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.github_plan_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "github_image_push" {
  name                 = "${local.name_prefix}-github-image-push"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.github_image_push_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "github_apply" {
  name                 = "${local.name_prefix}-github-apply"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.github_apply_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_policy" "github_plan" {
  name        = "${local.name_prefix}-github-plan"
  description = "Read-only Terraform plan permissions for ${local.ecr_repository_name}."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTerraformStateReadAndLock"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${local.state_bucket}/${local.state_prefix}*",
          "arn:aws:s3:::${local.state_bucket}/${local.state_prefix}*.tflock"
        ]
      },
      {
        Sid      = "AllowTerraformStateList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${local.state_bucket}"
        Condition = {
          StringLike = { "s3:prefix" = ["${local.state_prefix}*"] }
        }
      },
      {
        Sid      = "AllowEcsAndRelatedRead"
        Effect   = "Allow"
        Action   = ["ecs:Describe*", "ecs:List*", "logs:DescribeLogGroups", "logs:ListTagsForResource", "application-autoscaling:Describe*", "elasticloadbalancing:Describe*"]
        Resource = "*"
      },
      {
        Sid      = "AllowEcrRead"
        Effect   = "Allow"
        Action   = ["ecr:DescribeRepositories", "ecr:DescribeImages", "ecr:GetLifecyclePolicy", "ecr:ListTagsForResource"]
        Resource = aws_ecr_repository.service.arn
      },
      {
        Sid    = "AllowIamRead"
        Effect = "Allow"
        Action = ["iam:GetRole", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies"]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.name_prefix}-*",
          "arn:aws:iam::aws:policy/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "github_image_push" {
  name        = "${local.name_prefix}-github-image-push"
  description = "ECR push permissions for ${local.ecr_repository_name}."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowEcrAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "AllowRepositoryPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload", "ecr:DescribeImages", "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.service.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "github_apply" {
  name        = "${local.name_prefix}-github-apply"
  description = "Runtime apply/destroy permissions for Lab 06 ECS static site."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowTerraformStateMutation"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${local.state_bucket}/${local.state_prefix}*"
      },
      {
        Sid      = "AllowTerraformStateList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${local.state_bucket}"
        Condition = {
          StringLike = { "s3:prefix" = ["${local.state_prefix}*"] }
        }
      },
      {
        Sid    = "AllowEcsRuntimeManagement"
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster", "ecs:DeleteCluster", "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService",
          "ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition", "ecs:Describe*", "ecs:List*", "ecs:TagResource", "ecs:UntagResource",
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:DescribeLogGroups", "logs:TagResource", "logs:UntagResource",
          "application-autoscaling:RegisterScalableTarget", "application-autoscaling:DeregisterScalableTarget", "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DeleteScalingPolicy", "application-autoscaling:Describe*", "application-autoscaling:TagResource",
          "elasticloadbalancing:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowRuntimeIamManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:GetRole", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:TagRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.name_prefix}-*",
          "arn:aws:iam::aws:policy/*"
        ]
      },
      {
        Sid      = "AllowPassRuntimeRoleToEcs"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*"
        Condition = {
          StringEquals = { "iam:PassedToService" = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"] }
        }
      },
      {
        Sid      = "AllowRepositoryRead"
        Effect   = "Allow"
        Action   = ["ecr:DescribeRepositories", "ecr:DescribeImages", "ecr:GetLifecyclePolicy", "ecr:ListTagsForResource"]
        Resource = aws_ecr_repository.service.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_plan" {
  role       = aws_iam_role.github_plan.name
  policy_arn = aws_iam_policy.github_plan.arn
}

resource "aws_iam_role_policy_attachment" "github_image_push" {
  role       = aws_iam_role.github_image_push.name
  policy_arn = aws_iam_policy.github_image_push.arn
}

resource "aws_iam_role_policy_attachment" "github_apply" {
  role       = aws_iam_role.github_apply.name
  policy_arn = aws_iam_policy.github_apply.arn
}
