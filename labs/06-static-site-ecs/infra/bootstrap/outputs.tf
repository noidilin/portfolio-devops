output "ecr_repository_name" {
  description = "Name of the durable ECR repository."
  value       = aws_ecr_repository.service.name
}

output "ecr_repository_url" {
  description = "URL of the durable ECR repository."
  value       = aws_ecr_repository.service.repository_url
}

output "github_plan_role_arn" {
  description = "GitHub Actions OIDC role ARN for PR Terraform plans."
  value       = aws_iam_role.github_plan.arn
}

output "github_image_push_role_arn" {
  description = "GitHub Actions OIDC role ARN for pushing immutable images from main."
  value       = aws_iam_role.github_image_push.arn
}

output "github_apply_role_arn" {
  description = "GitHub Actions OIDC role ARN for approved apply/destroy jobs."
  value       = aws_iam_role.github_apply.arn
}
