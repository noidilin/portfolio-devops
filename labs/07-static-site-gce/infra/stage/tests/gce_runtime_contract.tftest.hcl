mock_provider "google" {}

run "gce_runtime_contract" {
  command = plan

  variables {
    gcp_project_id                  = "example-devops-labs"
    artifact_registry_repository_id = "devops-static-site-gce-stage-cidr-calculator"
    image_tag                       = "sha-0123456789abcdef0123456789abcdef01234567"
  }

  assert {
    condition     = output.container_image == "asia-northeast1-docker.pkg.dev/example-devops-labs/devops-static-site-gce-stage-cidr-calculator/cidr-calculator:sha-0123456789abcdef0123456789abcdef01234567"
    error_message = "stage must construct the tagged Artifact Registry image reference from explicit inputs."
  }

  assert {
    condition     = output.machine_type == "e2-micro" && output.boot_image_family == "ubuntu-2404-lts-amd64"
    error_message = "GCE runtime must default to e2-micro and Ubuntu 24.04 LTS."
  }

  assert {
    condition     = output.container_port == 80
    error_message = "GCE runtime must expose the shared static-site container on port 80."
  }

  assert {
    condition     = output.os_login_enabled && contains(output.iap_ssh_source_ranges, "35.235.240.0/20")
    error_message = "GCE runtime must enable OS Login and IAP-compatible SSH debugging."
  }

  assert {
    condition     = can(regex("--tunnel-through-iap", output.iap_ssh_command))
    error_message = "debug output must prefer IAP SSH rather than public SSH ingress."
  }
}
