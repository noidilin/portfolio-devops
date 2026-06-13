output "ecr_repository_name" {
  description = "Name of the durable canonical ECR repository."
  value       = aws_ecr_repository.service.name
}

output "ecr_repository_url" {
  description = "URL of the durable canonical ECR repository."
  value       = aws_ecr_repository.service.repository_url
}

output "artifact_registry_repository_id" {
  description = "Artifact Registry Docker repository ID for the GCP image mirror."
  value       = google_artifact_registry_repository.service.repository_id
}

output "artifact_registry_repository_name" {
  description = "Full Artifact Registry repository resource name."
  value       = google_artifact_registry_repository.service.name
}

output "artifact_registry_image_base" {
  description = "Base Docker image path for mirrored Lab 08 images. Append :sha-<git-sha>."
  value       = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.service.repository_id}/${var.service_name}"
}

output "gcp_plan_service_account_email" {
  description = "Plan service account email for GitHub WIF impersonation."
  value       = google_service_account.plan.email
}

output "gcp_apply_service_account_email" {
  description = "Apply service account email for approved GitHub WIF impersonation."
  value       = google_service_account.apply.email
}

output "gcp_workload_identity_provider" {
  description = "Shared GitHub Workload Identity provider resource name for auth actions."
  value       = local.gcp_wif_provider_name
}

output "gcp_plan_principal_set" {
  description = "Repository-scoped WIF principal set granted plan service account impersonation."
  value       = local.gcp_plan_principal_set
}

output "gcp_apply_principal" {
  description = "Protected-environment WIF principal granted apply service account impersonation."
  value       = local.gcp_apply_principal
}

output "gcp_plan_role_id" {
  description = "Project custom role ID bound to the plan service account."
  value       = google_project_iam_custom_role.plan.id
}

output "gcp_apply_role_id" {
  description = "Project custom role ID bound to the apply service account."
  value       = google_project_iam_custom_role.apply.id
}

output "gcp_state_bucket_name" {
  description = "Shared GCS Terraform state bucket consumed by Lab 08 runtime roots."
  value       = var.gcp_state_bucket_name
}

output "gcp_runtime_state_prefix" {
  description = "Recommended GCS backend prefix for the disposable Lab 08 runtime state."
  value       = local.gcp_state_prefix
}

output "github_plan_role_arn" {
  description = "AWS GitHub Actions OIDC role ARN for ECR-aware PR/main Terraform plans."
  value       = aws_iam_role.github_plan.arn
}

output "github_image_push_role_arn" {
  description = "AWS GitHub Actions OIDC role ARN for pushing immutable images to ECR from main."
  value       = aws_iam_role.github_image_push.arn
}

output "github_apply_role_arn" {
  description = "AWS GitHub Actions OIDC role ARN for approved bootstrap apply jobs."
  value       = aws_iam_role.github_apply.arn
}
