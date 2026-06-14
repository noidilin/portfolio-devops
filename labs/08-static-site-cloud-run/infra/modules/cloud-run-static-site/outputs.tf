output "service_name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.service.name
}

output "service_url" {
  description = "Public HTTPS URL exposed by Cloud Run."
  value       = google_cloud_run_v2_service.service.uri
}

output "container_image" {
  description = "Artifact Registry image deployed by Cloud Run."
  value       = var.container_image
}

output "runtime_service_account_email" {
  description = "Dedicated runtime service account email used by the Cloud Run revision."
  value       = google_service_account.runtime.email
}

output "min_instance_count" {
  description = "Configured minimum Cloud Run instance count."
  value       = var.min_instance_count
}

output "max_instance_count" {
  description = "Configured maximum Cloud Run instance count."
  value       = var.max_instance_count
}

output "container_port" {
  description = "Container port exposed to Cloud Run."
  value       = var.container_port
}
