mock_provider "google" {}

run "shared_bootstrap_contract" {
  command = plan

  variables {
    project_id         = "example-devops-labs"
    billing_account_id = "000000-000000-000000"
    github_repository  = "OWNER/REPO"
  }

  assert {
    condition     = google_storage_bucket.terraform_state.name == "example-devops-labs-tf-state"
    error_message = "The state bucket should default to the project-ID naming convention."
  }

  assert {
    condition     = google_storage_bucket.terraform_state.uniform_bucket_level_access == true && google_storage_bucket.terraform_state.public_access_prevention == "enforced" && google_storage_bucket.terraform_state.versioning[0].enabled == true
    error_message = "The state bucket must be versioned and locked down."
  }

  assert {
    condition = jsonencode(sort(tolist(local.required_project_services))) == jsonencode([
      "artifactregistry.googleapis.com",
      "billingbudgets.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "compute.googleapis.com",
      "iam.googleapis.com",
      "iamcredentials.googleapis.com",
      "iap.googleapis.com",
      "run.googleapis.com",
      "serviceusage.googleapis.com",
      "storage.googleapis.com",
      "sts.googleapis.com",
    ])
    error_message = "The bootstrap should manage only the agreed minimal project services."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository == 'OWNER/REPO' && assertion.repository_owner == 'OWNER'"
    error_message = "The GitHub WIF provider must be scoped to the configured repository."
  }

  assert {
    condition     = output.default_region == "asia-northeast1" && output.default_zone == "asia-northeast1-a"
    error_message = "Outputs must expose the default Tokyo region and zone."
  }
}
