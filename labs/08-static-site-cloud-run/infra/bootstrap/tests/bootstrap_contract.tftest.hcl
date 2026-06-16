mock_provider "aws" {}
mock_provider "google" {}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
  }
}

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
            "token.actions.githubusercontent.com:sub" = "repo:OWNER/REPO:environment:lab-08-stage"
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

run "lab08_bootstrap_contract" {
  command = plan

  variables {
    gcp_project_id           = "example-devops-labs"
    gcp_state_bucket_name    = "example-devops-labs-tf-state"
    github_repository        = "OWNER/REPO"
    github_wif_pool_name     = "projects/123456789012/locations/global/workloadIdentityPools/github-actions"
    github_wif_provider_name = "projects/123456789012/locations/global/workloadIdentityPools/github-actions/providers/github"
  }

  assert {
    condition     = aws_ecr_repository.service.name == "devops-static-site-cloud-run-stage-cidr-calculator" && aws_ecr_repository.service.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.service.image_scanning_configuration[0].scan_on_push == true && aws_ecr_repository.service.encryption_configuration[0].encryption_type == "AES256"
    error_message = "The ECR repository must follow the lab naming style and immutable scanned encrypted defaults."
  }

  assert {
    condition     = strcontains(aws_ecr_lifecycle_policy.service.policy, "Keep the most recent 20 SHA-tagged images") && strcontains(aws_ecr_lifecycle_policy.service.policy, "sha-")
    error_message = "The ECR lifecycle policy must retain recent SHA-tagged images."
  }

  assert {
    condition     = google_artifact_registry_repository.service.location == "asia-northeast1" && google_artifact_registry_repository.service.format == "DOCKER" && google_artifact_registry_repository.service.repository_id == "devops-static-site-cloud-run-stage-cidr-calculator"
    error_message = "The Artifact Registry repository must be a Docker mirror in the default GCP region."
  }

  assert {
    condition = anytrue([
      for policy in google_artifact_registry_repository.service.cleanup_policies :
      policy.id == "delete-old-sha-tags" && anytrue([
        for condition in policy.condition : condition.tag_state == "TAGGED" && contains(condition.tag_prefixes, "sha-") && condition.older_than == "2592000s"
      ])
      ]) && anytrue([
      for policy in google_artifact_registry_repository.service.cleanup_policies :
      policy.id == "keep-recent-versions" && anytrue([
        for recent in policy.most_recent_versions : recent.keep_count == 20
      ])
      ]) && anytrue([
      for policy in google_artifact_registry_repository.service.cleanup_policies :
      policy.id == "delete-untagged-images" && anytrue([
        for condition in policy.condition : condition.tag_state == "UNTAGGED" && condition.older_than == "86400s"
      ])
    ])
    error_message = "Artifact Registry cleanup must delete old sha tags, keep recent versions, and expire untagged images."
  }

  assert {
    condition     = google_service_account.plan.account_id == "devops-cloudrun-stage-plan" && google_service_account.apply.account_id == "devops-cloudrun-stage-apply"
    error_message = "Lab 08 must have separate canonical plan and apply service accounts."
  }

  assert {
    condition     = google_project_iam_custom_role.plan.role_id == "lab08CloudRunPlan" && google_project_iam_custom_role.apply.role_id == "lab08CloudRunApply"
    error_message = "Lab 08 must use pragmatic custom roles instead of Editor-like roles."
  }

  assert {
    condition     = contains(google_project_iam_custom_role.apply.permissions, "artifactregistry.repositories.downloadArtifacts") && contains(google_project_iam_custom_role.apply.permissions, "artifactregistry.repositories.uploadArtifacts") && contains(google_project_iam_custom_role.apply.permissions, "iam.serviceAccounts.actAs")
    error_message = "The durable Lab 08 apply role must mirror approved Docker images and act as the Cloud Run runtime service account."
  }

  assert {
    condition     = !contains(google_project_iam_custom_role.apply.permissions, "iam.roles.create") && !contains(google_project_iam_custom_role.apply.permissions, "iam.serviceAccounts.create") && !contains(google_project_iam_custom_role.apply.permissions, "iam.serviceAccounts.setIamPolicy") && !contains(google_project_iam_custom_role.apply.permissions, "resourcemanager.projects.setIamPolicy")
    error_message = "The durable Lab 08 apply role must not retain project/IAM bootstrap-admin permissions."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "token.actions.githubusercontent.com:aud") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "sts.amazonaws.com") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "repo:OWNER/REPO:pull_request") && strcontains(data.aws_iam_policy_document.github_plan_assume_role.json, "repo:OWNER/REPO:ref:refs/heads/main") && strcontains(data.aws_iam_policy_document.github_image_push_assume_role.json, "repo:OWNER/REPO:ref:refs/heads/main") && strcontains(data.aws_iam_policy_document.github_image_pull_assume_role.json, "repo:OWNER/REPO:environment:lab-08-stage")
    error_message = "AWS OIDC trust policies must stay scoped to PR/main for plan/push and protected environment for image pull."
  }

  assert {
    condition     = google_service_account_iam_member.github_plan_wif_pull_request.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/subject/repo:OWNER/REPO:pull_request" && google_service_account_iam_member.github_plan_wif_main.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/subject/repo:OWNER/REPO:ref:refs/heads/main" && google_service_account_iam_member.github_apply_wif.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/subject/repo:OWNER/REPO:environment:lab-08-stage"
    error_message = "GitHub WIF bindings must use explicit PR/main plan subjects and a protected environment apply subject."
  }

  assert {
    condition     = google_storage_bucket_iam_member.plan_state_read.role == "roles/storage.objectViewer" && length(google_storage_bucket_iam_member.plan_state_read.condition) == 0 && strcontains(google_storage_bucket_iam_member.plan_state_lock_bootstrap.condition[0].expression, "gcp/bootstrap/labs/08-static-site-cloud-run/") && strcontains(google_storage_bucket_iam_member.plan_state_lock_runtime.condition[0].expression, "gcp/runtime/labs/08-static-site-cloud-run/stage/") && strcontains(google_storage_bucket_iam_member.plan_state_lock_runtime.condition[0].expression, ".tflock") && strcontains(google_storage_bucket_iam_member.apply_state_runtime.condition[0].expression, "gcp/runtime/labs/08-static-site-cloud-run/stage/") && !contains(google_project_iam_custom_role.plan.permissions, "storage.objects.get") && !contains(google_project_iam_custom_role.plan.permissions, "storage.objects.list") && !contains(google_project_iam_custom_role.plan.permissions, "storage.objects.update") && !contains(google_project_iam_custom_role.apply.permissions, "storage.objects.update")
    error_message = "GCP state IAM must allow bucket-level read-only plan state access, lock-only bootstrap/runtime mutations, and apply runtime-only state access."
  }

  assert {
    condition     = output.artifact_registry_image_base == "asia-northeast1-docker.pkg.dev/example-devops-labs/devops-static-site-cloud-run-stage-cidr-calculator/cidr-calculator" && output.gcp_state_bucket_name == "example-devops-labs-tf-state" && output.gcp_runtime_state_prefix == "gcp/runtime/labs/08-static-site-cloud-run/stage/" && output.github_wif_provider_name == "projects/123456789012/locations/global/workloadIdentityPools/github-actions/providers/github"
    error_message = "Outputs must expose image base, shared WIF provider, and shared state details for future runtime Terraform."
  }
}
