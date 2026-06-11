output "ecr_repository_name" {
  description = "ECR repository name for the static site image."
  value       = data.aws_ecr_repository.service.name
}

output "ecr_repository_url" {
  description = "ECR repository URL for docker tag/push."
  value       = data.aws_ecr_repository.service.repository_url
}

output "container_image" {
  description = "Fully-qualified ECR image reference deployed by ECS Express Mode."
  value       = local.container_image
}

output "ecs_cluster_name" {
  description = "ECS cluster name used by the Express service."
  value       = aws_ecs_cluster.service.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN used by the Express service."
  value       = aws_ecs_cluster.service.arn
}

output "express_service_name" {
  description = "ECS Express Gateway service name."
  value       = aws_ecs_express_gateway_service.service.service_name
}

output "express_service_arn" {
  description = "ECS Express Gateway service ARN."
  value       = aws_ecs_express_gateway_service.service.service_arn
}

output "express_service_revision_arn" {
  description = "Current ECS Express service revision ARN."
  value       = aws_ecs_express_gateway_service.service.service_revision_arn
}

output "ingress_paths" {
  description = "Ingress endpoints exposed by ECS Express Mode."
  value       = aws_ecs_express_gateway_service.service.ingress_paths
}

output "service_url" {
  description = "Primary HTTPS URL exposed by ECS Express Mode."
  value       = try(aws_ecs_express_gateway_service.service.ingress_paths[0].endpoint, null)
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group receiving container stdout/stderr."
  value       = aws_cloudwatch_log_group.service.name
}

output "execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ECS task role ARN."
  value       = aws_iam_role.task.arn
}

output "infrastructure_role_arn" {
  description = "ECS Express infrastructure role ARN."
  value       = aws_iam_role.infrastructure.arn
}
