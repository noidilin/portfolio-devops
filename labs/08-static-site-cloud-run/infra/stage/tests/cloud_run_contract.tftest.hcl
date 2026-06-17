mock_provider "google" {}

run "cloud_run_runtime_contract" {
  command = plan

  variables {
    gcp_project_id                  = "example-devops-labs"
    gcp_region                      = "asia-northeast1"
    artifact_registry_repository_id = "devops-static-site-cloud-run-stage-cidr-calculator"
    image_tag                       = "sha-0123456789abcdef0123456789abcdef01234567"
  }

  assert {
    condition     = output.container_image == "asia-northeast1-docker.pkg.dev/example-devops-labs/devops-static-site-cloud-run-stage-cidr-calculator/cidr-calculator:sha-0123456789abcdef0123456789abcdef01234567"
    error_message = "stage must construct the tagged Artifact Registry image reference from explicit inputs."
  }

  assert {
    condition     = output.runtime_service_account_email == "devops-static-site-cloud-run-s@example-devops-labs.iam.gserviceaccount.com"
    error_message = "Stage must use the runtime service account pre-created by the bootstrap root."
  }

  assert {
    condition     = output.runtime_scaling.min_instance_count == 0 && output.runtime_scaling.max_instance_count == 2
    error_message = "Cloud Run runtime must scale to zero with a max instance guardrail of two."
  }

  assert {
    condition     = output.container_port == 80
    error_message = "Cloud Run must expose the shared static-site container on port 80."
  }

  assert {
    condition     = length(output.service_name) < 50
    error_message = "Cloud Run service IDs must stay below the API's 50-character limit."
  }
}
