mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version   = "2012-10-17"
        Statement = []
      })
    }
  }
}
mock_provider "google" {}

run "lab07_bootstrap_contract" {
  command = plan

  variables {
    gcp_project_id              = "example-devops-labs"
    gcp_project_number          = "123456789012"
    github_repository           = "OWNER/REPO"
    github_wif_pool_name        = "projects/123456789012/locations/global/workloadIdentityPools/github-actions"
    github_wif_provider_name    = "projects/123456789012/locations/global/workloadIdentityPools/github-actions/providers/github"
    terraform_state_bucket_name = "example-devops-labs-tf-state"
  }

  assert {
    condition     = aws_ecr_repository.service.name == "devops-static-site-gce-stage-cidr-calculator" && aws_ecr_repository.service.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.service.image_scanning_configuration[0].scan_on_push == true
    error_message = "Lab 07 should create an immutable scan-on-push ECR repository using the existing lab naming style."
  }

  assert {
    condition     = google_artifact_registry_repository.mirror.location == "asia-northeast1" && google_artifact_registry_repository.mirror.format == "DOCKER"
    error_message = "Lab 07 should create a Docker Artifact Registry repository in the default GCP region."
  }

  assert {
    condition = length(google_artifact_registry_repository.mirror.cleanup_policies) == 2 && length([
      for policy in google_artifact_registry_repository.mirror.cleanup_policies : policy
      if policy.id == "delete-old-sha-tags" && policy.action == "DELETE" && tolist(policy.condition)[0].tag_prefixes[0] == "sha-"
      ]) == 1 && length([
      for policy in google_artifact_registry_repository.mirror.cleanup_policies : policy
      if policy.id == "keep-recent-versions" && policy.action == "KEEP" && tolist(policy.most_recent_versions)[0].keep_count == 20
    ]) == 1
    error_message = "Artifact Registry cleanup should bound SHA-tagged image growth while retaining recent versions."
  }

  assert {
    condition     = google_service_account.plan.account_id == "devops-gce-stage-plan" && google_service_account.apply.account_id == "devops-gce-stage-apply"
    error_message = "Lab 07 should create separate GCP plan and apply service accounts."
  }

  assert {
    condition     = aws_iam_role.github_plan.name == "devops-static-site-gce-stage-github-plan" && aws_iam_policy.github_plan.name == "devops-static-site-gce-stage-github-plan"
    error_message = "Lab 07 should create an AWS OIDC plan role so CI can read ECR through AWS credentials instead of GCP credentials."
  }

  assert {
    condition     = contains(google_service_account_iam_binding.plan_wif.members, "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/subject/repo:OWNER/REPO:pull_request") && contains(google_service_account_iam_binding.apply_wif.members, "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-actions/subject/repo:OWNER/REPO:environment:lab-07-stage")
    error_message = "GitHub WIF bindings should scope plan to PR/main contexts and apply to the protected Lab 07 environment."
  }

  assert {
    condition     = contains(google_project_iam_custom_role.plan.permissions, "storage.buckets.getIamPolicy") && contains(google_project_iam_custom_role.apply.permissions, "storage.buckets.getIamPolicy") && contains(google_project_iam_custom_role.apply.permissions, "storage.buckets.setIamPolicy")
    error_message = "Plan/apply identities need bucket IAM read access for Terraform refresh, and apply needs setIamPolicy to manage state bucket IAM members."
  }

  assert {
    condition     = output.artifact_registry_image_base == "asia-northeast1-docker.pkg.dev/example-devops-labs/devops-static-site-gce-stage-cidr-calculator/cidr-calculator" && output.github_wif_provider_name == "projects/123456789012/locations/global/workloadIdentityPools/github-actions/providers/github"
    error_message = "Outputs should expose image base and shared WIF provider references for future workflows."
  }
}
