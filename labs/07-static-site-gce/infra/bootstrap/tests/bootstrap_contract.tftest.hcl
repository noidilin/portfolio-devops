mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}
mock_provider "google" {}

override_data {
  target = data.aws_iam_policy_document.github_plan_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:OWNER/REPO:pull_request",
              "repo:OWNER/REPO:ref:refs/heads/main",
            ]
          }
        }
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
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
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:OWNER/REPO:ref:refs/heads/main"
          }
        }
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }
      }]
    })
  }
}

override_data {
  target = data.aws_iam_policy_document.github_image_pull_assume_role
  values = {
    json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:OWNER/REPO:environment:lab-07-stage"
          }
        }
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }
      }]
    })
  }
}

run "lab07_bootstrap_contract" {
  command = plan

  variables {
    gcp_project_id           = "example-devops-labs"
    gcp_project_number       = "123456789012"
    github_repository        = "OWNER/REPO"
    github_wif_pool_name     = "projects/123456789012/locations/global/workloadIdentityPools/github-actions"
    github_wif_provider_name = "projects/123456789012/locations/global/workloadIdentityPools/github-actions/providers/github"
    gcp_state_bucket_name    = "example-devops-labs-tf-state"
  }

  assert {
    condition     = aws_ecr_repository.service.name == "devops-static-site-gce-stage-cidr-calculator" && aws_ecr_repository.service.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.service.image_scanning_configuration[0].scan_on_push == true && aws_ecr_repository.service.encryption_configuration[0].encryption_type == "AES256"
    error_message = "Lab 07 should create an immutable, scan-on-push, AES256-encrypted canonical ECR repository using the lab naming style."
  }

  assert {
    condition     = strcontains(aws_ecr_lifecycle_policy.service.policy, "sha-") && strcontains(aws_ecr_lifecycle_policy.service.policy, "imageCountMoreThan") && strcontains(aws_ecr_lifecycle_policy.service.policy, "20") && strcontains(aws_ecr_lifecycle_policy.service.policy, "untagged")
    error_message = "ECR lifecycle should keep the most recent 20 SHA-tagged images and expire untagged images after one day."
  }

  assert {
    condition     = aws_iam_role.github_plan.name == "devops-static-site-gce-stage-github-plan" && aws_iam_role.github_image_push.name == "devops-static-site-gce-stage-github-image-push" && aws_iam_role.github_image_pull.name == "devops-static-site-gce-stage-github-image-pull"
    error_message = "Lab 07 should create canonical AWS OIDC plan, image-push, and image-pull roles."
  }

  assert {
    condition     = aws_iam_role.github_plan.permissions_boundary == "arn:aws:iam::123456789012:policy/lab-gitops-oidc-apply-permissions-boundary" && aws_iam_role.github_image_push.permissions_boundary == aws_iam_role.github_plan.permissions_boundary && aws_iam_role.github_image_pull.permissions_boundary == aws_iam_role.github_plan.permissions_boundary
    error_message = "All Lab 07 GitHub OIDC roles should use the lab permissions boundary."
  }

  assert {
    condition     = google_artifact_registry_repository.service.location == "asia-northeast1" && google_artifact_registry_repository.service.format == "DOCKER"
    error_message = "Lab 07 should create a Docker Artifact Registry repository in the default GCP region."
  }

  assert {
    condition = length(google_artifact_registry_repository.service.cleanup_policies) == 3 && length([
      for policy in google_artifact_registry_repository.service.cleanup_policies : policy
      if policy.id == "delete-old-sha-tags" && policy.action == "DELETE" && tolist(policy.condition)[0].tag_state == "TAGGED" && tolist(policy.condition)[0].tag_prefixes[0] == "sha-"
      ]) == 1 && length([
      for policy in google_artifact_registry_repository.service.cleanup_policies : policy
      if policy.id == "keep-recent-versions" && policy.action == "KEEP" && tolist(policy.most_recent_versions)[0].keep_count == 20
      ]) == 1 && length([
      for policy in google_artifact_registry_repository.service.cleanup_policies : policy
      if policy.id == "delete-untagged-images" && policy.action == "DELETE" && tolist(policy.condition)[0].tag_state == "UNTAGGED"
    ]) == 1
    error_message = "Artifact Registry cleanup should keep recent versions, delete old sha-* tags, and delete untagged images."
  }

  assert {
    condition     = google_service_account.plan.account_id == "devops-gce-stage-plan" && google_service_account.apply.account_id == "devops-gce-stage-apply"
    error_message = "Lab 07 should create canonical devops-<runtime>-<environment>-<purpose> GCP plan and apply service accounts."
  }

  assert {
    condition     = google_service_account_iam_member.github_plan_wif_pull_request.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/subject/repo:OWNER/REPO:pull_request" && google_service_account_iam_member.github_plan_wif_main.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/subject/repo:OWNER/REPO:ref:refs/heads/main" && google_service_account_iam_member.github_apply_wif.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/subject/repo:OWNER/REPO:environment:lab-07-stage"
    error_message = "GCP WIF grants must use additive service-account IAM members with explicit PR/main/protected-environment subjects."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "token.actions.githubusercontent.com:aud") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "sts.amazonaws.com") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "repo:OWNER/REPO:pull_request") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "repo:OWNER/REPO:ref:refs/heads/main") && !strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "job_workflow_ref")
    error_message = "AWS plan role trust must use only the GitHub OIDC audience plus PR/main subjects, with no workflow-file-specific job_workflow_ref condition."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.github_image_push_assume_role.json, "sts.amazonaws.com") && strcontains(data.aws_iam_policy_document.github_image_push_assume_role.json, "repo:OWNER/REPO:ref:refs/heads/main") && strcontains(data.aws_iam_policy_document.github_image_pull_assume_role.json, "repo:OWNER/REPO:environment:lab-07-stage") && aws_iam_role.github_image_pull.assume_role_policy == data.aws_iam_policy_document.github_image_pull_assume_role.json
    error_message = "Image-push trust must stay on main and image-pull trust must stay scoped to the protected Lab 07 environment."
  }

  assert {
    condition     = contains(google_project_iam_custom_role.plan.permissions, "storage.buckets.getIamPolicy") && contains(google_project_iam_custom_role.apply.permissions, "storage.buckets.getIamPolicy") && contains(google_project_iam_custom_role.apply.permissions, "artifactregistry.repositories.setIamPolicy") && contains(google_project_iam_custom_role.plan.permissions, "artifactregistry.repositories.getIamPolicy") && contains(google_project_iam_custom_role.apply.permissions, "compute.subnetworks.useExternalIp")
    error_message = "Plan/apply custom roles need IAM policy access for Terraform-managed IAM members and external-IP subnet use for the public GCE instance."
  }

  assert {
    condition     = output.artifact_registry_image_base == "asia-northeast1-docker.pkg.dev/example-devops-labs/devops-static-site-gce-stage-cidr-calculator/cidr-calculator" && output.github_wif_provider_name == "projects/123456789012/locations/global/workloadIdentityPools/github-actions/providers/github" && output.gcp_state_bucket_name == "example-devops-labs-tf-state" && output.gcp_runtime_state_prefix == "gcp/runtime/labs/07-static-site-gce/stage/"
    error_message = "Outputs should expose canonical state bucket/prefix names plus image base and shared WIF provider references."
  }

  assert {
    condition     = lookup(google_artifact_registry_repository.service.labels, "project") == "static-site-gce" && lookup(google_artifact_registry_repository.service.labels, "environment") == "stage" && lookup(google_artifact_registry_repository.service.labels, "lab") == "07-static-site-gce" && lookup(google_artifact_registry_repository.service.labels, "managed_by") == "terraform" && lookup(google_artifact_registry_repository.service.labels, "service") == "cidr-calculator"
    error_message = "GCP labels must preserve the canonical semantic vocabulary and values (project, environment, lab, managed_by, service)."
  }
}

run "lab07_bootstrap_state_scope_contract" {
  command = plan

  variables {
    gcp_project_id           = "example-devops-labs"
    gcp_project_number       = "123456789012"
    github_repository        = "OWNER/REPO"
    github_wif_pool_name     = "projects/123456789012/locations/global/workloadIdentityPools/github-actions"
    github_wif_provider_name = "projects/123456789012/locations/global/workloadIdentityPools/github-actions/providers/github"
    gcp_state_bucket_name    = "example-devops-labs-tf-state"
  }

  assert {
    condition     = google_storage_bucket_iam_member.plan_state_read.role == "roles/storage.objectViewer" && length(google_storage_bucket_iam_member.plan_state_read.condition) == 0
    error_message = "Plan service account must get bucket-level read-only objectViewer for state reads, with no condition."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.plan_state_lock_bootstrap.condition) == 1 && strcontains(tolist(google_storage_bucket_iam_member.plan_state_lock_bootstrap.condition)[0].expression, "gcp/bootstrap/labs/07-static-site-gce/") && strcontains(tolist(google_storage_bucket_iam_member.plan_state_lock_bootstrap.condition)[0].expression, ".tflock") && tolist(google_storage_bucket_iam_member.plan_state_lock_bootstrap.condition)[0].expression != tolist(google_storage_bucket_iam_member.plan_state_lock_runtime.condition)[0].expression
    error_message = "Plan lock grant for the bootstrap prefix must be conditional on .tflock files under the Lab 07 bootstrap state prefix."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.plan_state_lock_runtime.condition) == 1 && strcontains(tolist(google_storage_bucket_iam_member.plan_state_lock_runtime.condition)[0].expression, "gcp/runtime/labs/07-static-site-gce/stage/") && strcontains(tolist(google_storage_bucket_iam_member.plan_state_lock_runtime.condition)[0].expression, ".tflock")
    error_message = "Plan lock grant for the runtime prefix must be conditional on .tflock files under the Lab 07 runtime state prefix."
  }

  assert {
    condition     = google_storage_bucket_iam_member.apply_state_read.role == "roles/storage.objectViewer" && length(google_storage_bucket_iam_member.apply_state_read.condition) == 0 && google_storage_bucket_iam_member.apply_state_runtime.role == "roles/storage.objectAdmin" && length(google_storage_bucket_iam_member.apply_state_runtime.condition) == 1 && strcontains(tolist(google_storage_bucket_iam_member.apply_state_runtime.condition)[0].expression, "gcp/runtime/labs/07-static-site-gce/stage/") && !strcontains(tolist(google_storage_bucket_iam_member.apply_state_runtime.condition)[0].expression, ".tflock")
    error_message = "Apply service account must get bucket-level read/list for Terraform workspace discovery and objectAdmin only for runtime state mutations."
  }

  assert {
    condition     = !strcontains(tolist(google_storage_bucket_iam_member.apply_state_runtime.condition)[0].expression, "gcp/bootstrap/labs/07-static-site-gce/")
    error_message = "Apply state grant must not reach the Lab 07 bootstrap state prefix."
  }

  assert {
    condition     = !contains(google_project_iam_custom_role.plan.permissions, "storage.objects.get") && !contains(google_project_iam_custom_role.plan.permissions, "storage.objects.list")
    error_message = "Plan custom role must not carry broad state-object read permissions; reads flow from the bucket-level objectViewer grant."
  }

  assert {
    condition     = !contains(google_project_iam_custom_role.apply.permissions, "storage.objects.create") && !contains(google_project_iam_custom_role.apply.permissions, "storage.objects.delete") && !contains(google_project_iam_custom_role.apply.permissions, "storage.objects.update") && !contains(google_project_iam_custom_role.apply.permissions, "storage.buckets.setIamPolicy")
    error_message = "Apply custom role must not carry broad state-object mutation permissions; apply mutates only via the runtime-prefix conditional grant."
  }
}
