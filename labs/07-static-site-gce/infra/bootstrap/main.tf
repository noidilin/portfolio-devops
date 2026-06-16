resource "aws_ecr_repository" "service" {
  name                 = local.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.aws_tags
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

  tags = local.aws_tags
}

resource "aws_iam_role" "github_image_push" {
  name                 = "${local.name_prefix}-github-image-push"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.github_image_push_assume_role.json

  tags = local.aws_tags
}

resource "aws_iam_role" "github_image_pull" {
  name                 = "${local.name_prefix}-github-image-pull"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.github_image_pull_assume_role.json

  tags = local.aws_tags
}

resource "aws_iam_policy" "github_plan" {
  name        = "${local.name_prefix}-github-plan"
  description = "Read-only AWS permissions for ${local.ecr_repository_name} bootstrap plans."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowEcrRead"
        Effect   = "Allow"
        Action   = ["ecr:DescribeRepositories", "ecr:DescribeImages", "ecr:GetLifecyclePolicy", "ecr:ListTagsForResource"]
        Resource = aws_ecr_repository.service.arn
      },
      {
        Sid    = "AllowBootstrapIamRead"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListPolicyTags",
          "iam:ListPolicyVersions",
          "iam:ListRolePolicies",
          "iam:ListRoleTags"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.name_prefix}-*",
          local.permissions_boundary_arn
        ]
      }
    ]
  })

  tags = local.aws_tags
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
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.service.arn
      }
    ]
  })

  tags = local.aws_tags
}

resource "aws_iam_policy" "github_image_pull" {
  name        = "${local.name_prefix}-github-image-pull"
  description = "ECR pull permissions for ${local.ecr_repository_name}."

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
        Sid    = "AllowRepositoryPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = aws_ecr_repository.service.arn
      }
    ]
  })

  tags = local.aws_tags
}

resource "aws_iam_role_policy_attachment" "github_plan" {
  role       = aws_iam_role.github_plan.name
  policy_arn = aws_iam_policy.github_plan.arn
}

resource "aws_iam_role_policy_attachment" "github_image_push" {
  role       = aws_iam_role.github_image_push.name
  policy_arn = aws_iam_policy.github_image_push.arn
}

resource "aws_iam_role_policy_attachment" "github_image_pull" {
  role       = aws_iam_role.github_image_pull.name
  policy_arn = aws_iam_policy.github_image_pull.arn
}

resource "google_artifact_registry_repository" "service" {
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = local.artifact_repository_id
  description   = "GCP mirror for ${aws_ecr_repository.service.name}."
  format        = "DOCKER"
  labels        = local.gcp_labels

  cleanup_policies {
    id     = "delete-old-sha-tags"
    action = "DELETE"

    condition {
      tag_state    = "TAGGED"
      tag_prefixes = ["sha-"]
      older_than   = var.artifact_registry_delete_older_than
    }
  }

  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.artifact_registry_keep_count
    }
  }

  cleanup_policies {
    id     = "delete-untagged-images"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = var.artifact_registry_untagged_delete_older_than
    }
  }
}

resource "google_service_account" "plan" {
  project      = var.gcp_project_id
  account_id   = local.plan_service_account_id
  display_name = "Lab 07 GCE Terraform plan"
  description  = "Read-oriented planning identity for Lab 07 GCE bootstrap and runtime Terraform."
}

resource "google_service_account" "apply" {
  project      = var.gcp_project_id
  account_id   = local.apply_service_account_id
  display_name = "Lab 07 GCE Terraform apply"
  description  = "Approved apply/destroy identity for Lab 07 GCE bootstrap and runtime Terraform."
}

resource "google_project_iam_custom_role" "plan" {
  project     = var.gcp_project_id
  role_id     = local.plan_role_id
  title       = "Lab 07 GCE Terraform plan"
  description = "Pragmatic read permissions for Lab 07 GCE bootstrap/runtime Terraform plans."
  stage       = "GA"

  permissions = local.plan_permissions
}

resource "google_project_iam_custom_role" "apply" {
  project     = var.gcp_project_id
  role_id     = local.apply_role_id
  title       = "Lab 07 GCE Terraform apply"
  description = "Pragmatic mutation permissions for Lab 07 GCE bootstrap/runtime Terraform applies."
  stage       = "GA"

  permissions = local.apply_permissions
}

resource "google_project_iam_member" "plan" {
  project = var.gcp_project_id
  role    = google_project_iam_custom_role.plan.name
  member  = google_service_account.plan.member
}

resource "google_project_iam_member" "apply" {
  project = var.gcp_project_id
  role    = google_project_iam_custom_role.apply.name
  member  = google_service_account.apply.member
}

resource "google_storage_bucket_iam_member" "plan_state_read" {
  bucket = var.gcp_state_bucket_name
  role   = "roles/storage.objectViewer"
  member = google_service_account.plan.member
}

resource "google_storage_bucket_iam_member" "plan_state_lock_bootstrap" {
  bucket = var.gcp_state_bucket_name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.plan.member

  condition {
    title       = "BootstrapStateLockFiles"
    description = "Allow PR plans to create and delete Terraform GCS lock files for this bootstrap prefix only."
    expression  = "resource.type == \"storage.googleapis.com/Object\" && resource.name.startsWith(\"projects/_/buckets/${var.gcp_state_bucket_name}/objects/${local.gcp_bootstrap_prefix}\") && resource.name.endsWith(\".tflock\")"
  }
}

resource "google_storage_bucket_iam_member" "plan_state_lock_runtime" {
  bucket = var.gcp_state_bucket_name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.plan.member

  condition {
    title       = "RuntimeStateLockFiles"
    description = "Allow PR plans to create and delete Terraform GCS lock files for this runtime state prefix."
    expression  = "resource.type == \"storage.googleapis.com/Object\" && resource.name.startsWith(\"projects/_/buckets/${var.gcp_state_bucket_name}/objects/${local.gcp_state_prefix}\") && resource.name.endsWith(\".tflock\")"
  }
}

resource "google_storage_bucket_iam_member" "apply_state_runtime" {
  bucket = var.gcp_state_bucket_name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.apply.member

  condition {
    title       = "RuntimeStateAccess"
    description = "Allow runtime apply to read/write and lock Terraform state objects for the runtime state prefix only."
    expression  = "resource.type == \"storage.googleapis.com/Object\" && resource.name.startsWith(\"projects/_/buckets/${var.gcp_state_bucket_name}/objects/${local.gcp_state_prefix}\")"
  }
}

resource "google_service_account_iam_member" "github_plan_wif_pull_request" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.plan_wif_members[0]
}

resource "google_service_account_iam_member" "github_plan_wif_main" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.plan_wif_members[1]
}

resource "google_service_account_iam_member" "github_apply_wif" {
  service_account_id = google_service_account.apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.apply_wif_members[0]
}
