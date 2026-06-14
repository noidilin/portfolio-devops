output "artifact_registry_image_base" {
  description = "Base Artifact Registry image path. The deployed tag is appended separately."
  value       = local.artifact_registry_image_base
}

output "container_image" {
  description = "Fully-qualified Artifact Registry image reference deployed by Cloud Run."
  value       = module.runtime.container_image
}

output "service_name" {
  description = "Cloud Run service name."
  value       = module.runtime.service_name
}

output "service_url" {
  description = "Public HTTPS URL exposed by Cloud Run."
  value       = module.runtime.service_url
}

output "runtime_service_account_email" {
  description = "Dedicated runtime service account email used by Cloud Run revisions."
  value       = module.runtime.runtime_service_account_email
}

output "runtime_scaling" {
  description = "Configured Cloud Run scale-to-zero and max-instance guardrails."
  value = {
    min_instance_count = module.runtime.min_instance_count
    max_instance_count = module.runtime.max_instance_count
  }
}

output "container_port" {
  description = "Container port exposed to Cloud Run."
  value       = module.runtime.container_port
}

output "docker_mirror_commands" {
  description = "Example commands to mirror an already-pushed ECR image tag into Lab 08 Artifact Registry. Replace the ECR URL before running."
  value = [
    "docker pull REPLACE_WITH_ECR_REPOSITORY_URL:${var.image_tag}",
    "docker tag REPLACE_WITH_ECR_REPOSITORY_URL:${var.image_tag} ${local.container_image}",
    "gcloud auth configure-docker ${var.gcp_region}-docker.pkg.dev --project ${var.gcp_project_id}",
    "docker push ${local.container_image}"
  ]
}

output "smoke_test_command" {
  description = "Command to verify the deployed static site returns the expected HTML."
  value       = "curl -fsS ${module.runtime.service_url} | grep -F 'CIDR Calculator'"
}

output "describe_service_command" {
  description = "Command to inspect Cloud Run service configuration and URL."
  value       = "gcloud run services describe ${module.runtime.service_name} --project ${var.gcp_project_id} --region ${var.gcp_region} --format='yaml(status.url,status.conditions,spec.template.spec.containers,spec.template.metadata.annotations)'"
}

output "list_revisions_command" {
  description = "Command to inspect Cloud Run revisions for the deployed image tag."
  value       = "gcloud run revisions list --service ${module.runtime.service_name} --project ${var.gcp_project_id} --region ${var.gcp_region}"
}
