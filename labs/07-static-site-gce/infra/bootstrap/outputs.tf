output "ecr_repository_name" {
  description = "Name of the durable canonical ECR repository."
  value       = aws_ecr_repository.service.name
}

output "ecr_repository_arn" {
  description = "ARN of the durable canonical ECR repository."
  value       = aws_ecr_repository.service.arn
}

output "ecr_repository_url" {
  description = "URL of the durable canonical ECR repository."
  value       = aws_ecr_repository.service.repository_url
}

output "github_plan_role_arn" {
  description = "GitHub Actions OIDC role ARN for ECR-aware PR/main Terraform plans."
  value       = aws_iam_role.github_plan.arn
}

output "github_image_push_role_arn" {
  description = "GitHub Actions OIDC role ARN for pushing immutable canonical images to ECR from main."
  value       = aws_iam_role.github_image_push.arn
}

output "github_image_pull_role_arn" {
  description = "GitHub Actions OIDC role ARN for pulling immutable canonical images from ECR from main."
  value       = aws_iam_role.github_image_pull.arn
}

output "artifact_registry_repository_id" {
  description = "Artifact Registry Docker repository ID used as the GCE mirror destination."
  value       = google_artifact_registry_repository.mirror.repository_id
}

output "artifact_registry_repository_name" {
  description = "Full Artifact Registry repository resource name."
  value       = google_artifact_registry_repository.mirror.name
}

output "artifact_registry_image_base" {
  description = "Base Docker image path for mirrored images consumed by future GCE runtime Terraform."
  value       = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.mirror.repository_id}/${var.service_name}"
}

output "gcp_plan_service_account_email" {
  description = "Email of the Lab 07 GCP Terraform plan service account."
  value       = google_service_account.plan.email
}

output "gcp_apply_service_account_email" {
  description = "Email of the Lab 07 GCP Terraform apply service account."
  value       = google_service_account.apply.email
}

output "gcp_plan_role_name" {
  description = "Full name of the pragmatic custom GCP plan role."
  value       = google_project_iam_custom_role.plan.name
}

output "gcp_apply_role_name" {
  description = "Full name of the pragmatic custom GCP apply role."
  value       = google_project_iam_custom_role.apply.name
}

output "gcp_project_number" {
  description = "GCP project number used in shared WIF resource names."
  value       = var.gcp_project_number
}

output "github_wif_provider_name" {
  description = "Shared GitHub Workload Identity Federation provider name for google-github-actions/auth."
  value       = var.github_wif_provider_name
}

output "github_wif_plan_members" {
  description = "GitHub OIDC subjects allowed to impersonate the plan service account."
  value       = local.plan_wif_members
}

output "github_wif_apply_members" {
  description = "GitHub OIDC subjects allowed to impersonate the protected-environment apply service account."
  value       = local.apply_wif_members
}

output "terraform_state_bucket_name" {
  description = "Shared GCS Terraform state bucket used by this bootstrap and future Lab 07 runtime roots."
  value       = var.terraform_state_bucket_name
}

output "runtime_state_prefix" {
  description = "Suggested GCS state prefix for the future Lab 07 GCE runtime root."
  value       = local.gcp_state_prefix
}
