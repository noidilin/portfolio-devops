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

resource "google_artifact_registry_repository" "service" {
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = local.artifact_repository_id
  description   = "Lab 08 Cloud Run mirror for ${var.service_name} images."
  format        = "DOCKER"
  labels        = local.gcp_labels

  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.artifact_cleanup_keep_count
    }
  }

  cleanup_policies {
    id     = "delete-untagged-after-one-day"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "86400s"
    }
  }
}

resource "google_service_account" "plan" {
  project      = var.gcp_project_id
  account_id   = local.plan_service_account_id
  display_name = "Lab 08 Cloud Run Terraform plan"
  description  = "Read-oriented identity for Lab 08 Cloud Run bootstrap and runtime plans."
}

resource "google_service_account" "apply" {
  project      = var.gcp_project_id
  account_id   = local.apply_service_account_id
  display_name = "Lab 08 Cloud Run Terraform apply"
  description  = "Approved identity for Lab 08 Cloud Run bootstrap and runtime applies/destroys."
}

resource "google_project_iam_custom_role" "plan" {
  project     = var.gcp_project_id
  role_id     = local.plan_custom_role_id
  title       = "Lab 08 Cloud Run Terraform plan"
  description = "Pragmatic read permissions for Lab 08 Cloud Run Terraform plans."
  stage       = "GA"

  permissions = [
    "artifactregistry.dockerimages.get",
    "artifactregistry.dockerimages.list",
    "artifactregistry.repositories.get",
    "artifactregistry.repositories.list",
    "iam.roles.get",
    "iam.roles.list",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.list",
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "run.services.get",
    "run.services.getIamPolicy",
    "run.services.list",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "storage.buckets.get",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

resource "google_project_iam_custom_role" "apply" {
  project     = var.gcp_project_id
  role_id     = local.apply_custom_role_id
  title       = "Lab 08 Cloud Run Terraform apply"
  description = "Pragmatic mutation permissions for Lab 08 Cloud Run Terraform applies."
  stage       = "GA"

  permissions = [
    "artifactregistry.dockerimages.get",
    "artifactregistry.dockerimages.list",
    "artifactregistry.repositories.create",
    "artifactregistry.repositories.delete",
    "artifactregistry.repositories.get",
    "artifactregistry.repositories.list",
    "artifactregistry.repositories.update",
    "iam.roles.create",
    "iam.roles.delete",
    "iam.roles.get",
    "iam.roles.list",
    "iam.roles.undelete",
    "iam.roles.update",
    "iam.serviceAccounts.actAs",
    "iam.serviceAccounts.create",
    "iam.serviceAccounts.delete",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.list",
    "iam.serviceAccounts.setIamPolicy",
    "iam.serviceAccounts.update",
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "resourcemanager.projects.setIamPolicy",
    "run.operations.get",
    "run.routes.get",
    "run.routes.list",
    "run.services.create",
    "run.services.delete",
    "run.services.get",
    "run.services.getIamPolicy",
    "run.services.list",
    "run.services.setIamPolicy",
    "run.services.update",
    "run.configurations.get",
    "run.configurations.list",
    "run.revisions.get",
    "run.revisions.list",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "storage.buckets.get",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
  ]
}

resource "google_project_iam_member" "plan" {
  project = var.gcp_project_id
  role    = google_project_iam_custom_role.plan.id
  member  = google_service_account.plan.member
}

resource "google_project_iam_member" "apply" {
  project = var.gcp_project_id
  role    = google_project_iam_custom_role.apply.id
  member  = google_service_account.apply.member
}

resource "google_service_account_iam_member" "github_plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.gcp_plan_principal_set
}

resource "google_service_account_iam_member" "github_apply_wif" {
  service_account_id = google_service_account.apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.gcp_apply_principal
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

resource "aws_iam_role" "github_apply" {
  name                 = "${local.name_prefix}-github-apply"
  permissions_boundary = local.permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.github_apply_assume_role.json

  tags = local.aws_tags
}

resource "aws_iam_policy" "github_plan" {
  name        = "${local.name_prefix}-github-plan"
  description = "Read-only Terraform plan permissions for ${local.ecr_repository_name}."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowEcrRead"
        Effect   = "Allow"
        Action   = ["ecr:DescribeRepositories", "ecr:DescribeImages", "ecr:GetLifecyclePolicy", "ecr:ListTagsForResource"]
        Resource = aws_ecr_repository.service.arn
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
          "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload", "ecr:DescribeImages", "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.service.arn
      }
    ]
  })

  tags = local.aws_tags
}

resource "aws_iam_policy" "github_apply" {
  name        = "${local.name_prefix}-github-apply"
  description = "Apply permissions for Lab 08 Cloud Run bootstrap AWS resources."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowRepositoryRead"
        Effect   = "Allow"
        Action   = ["ecr:DescribeRepositories", "ecr:DescribeImages", "ecr:GetLifecyclePolicy", "ecr:ListTagsForResource"]
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

resource "aws_iam_role_policy_attachment" "github_apply" {
  role       = aws_iam_role.github_apply.name
  policy_arn = aws_iam_policy.github_apply.arn
}
