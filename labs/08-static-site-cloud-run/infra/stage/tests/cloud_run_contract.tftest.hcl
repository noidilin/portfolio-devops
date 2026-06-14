mock_provider "google" {}

run "cloud_run_runtime_contract" {
  command = plan

  variables {
    gcp_project_id                  = "example-devops-labs"
    artifact_registry_repository_id = "devops-static-site-cloud-run-stage-cidr-calculator"
    image_tag                       = "sha-0123456789abcdef0123456789abcdef01234567"
  }

  assert {
    condition     = output.container_image == "asia-northeast1-docker.pkg.dev/example-devops-labs/devops-static-site-cloud-run-stage-cidr-calculator/cidr-calculator:sha-0123456789abcdef0123456789abcdef01234567"
    error_message = "stage must construct the tagged Artifact Registry image reference from explicit inputs."
  }

  assert {
    condition     = output.runtime_scaling.min_instance_count == 0 && output.runtime_scaling.max_instance_count == 2
    error_message = "Cloud Run runtime must scale to zero with a max instance guardrail of two."
  }

  assert {
    condition     = output.container_port == 80
    error_message = "Cloud Run must expose the shared static-site container on port 80."
  }
}
