output "project_id" {
  description = "Bootstrapped GCP project ID."
  value       = var.project_id
}

output "project_number" {
  description = "Bootstrapped GCP project number."
  value       = data.google_project.current.number
}

output "default_region" {
  description = "Default GCP region for later lab roots."
  value       = var.default_region
}

output "default_zone" {
  description = "Default GCP zone for later lab roots."
  value       = var.default_zone
}

output "state_bucket_name" {
  description = "Name of the shared GCS Terraform state bucket."
  value       = google_storage_bucket.terraform_state.name
}

output "state_bucket_url" {
  description = "GCS URL for the shared Terraform state bucket."
  value       = google_storage_bucket.terraform_state.url
}

output "github_repository" {
  description = "GitHub repository allowed by the shared WIF provider."
  value       = var.github_repository
}

output "github_wif_pool_id" {
  description = "ID of the shared GitHub Workload Identity Federation pool."
  value       = google_iam_workload_identity_pool.github.workload_identity_pool_id
}

output "github_wif_pool_name" {
  description = "Full resource name of the shared GitHub Workload Identity Federation pool."
  value       = google_iam_workload_identity_pool.github.name
}

output "github_wif_provider_id" {
  description = "ID of the shared GitHub Workload Identity Federation provider."
  value       = google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id
}

output "github_wif_provider_name" {
  description = "Full provider resource name used by GitHub Actions authentication."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_wif_principal_set" {
  description = "Principal set URI for IAM bindings that trust this repository through the shared WIF pool."
  value       = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

output "common_labels" {
  description = "Common lowercase labels for later GCP lab resources."
  value       = var.labels
}

output "required_project_services" {
  description = "Minimal project APIs managed by this shared bootstrap."
  value       = sort(tolist(local.required_project_services))
}
