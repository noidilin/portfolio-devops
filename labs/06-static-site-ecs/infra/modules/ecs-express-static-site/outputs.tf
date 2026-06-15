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

output "cpu" {
  description = "ECS Express task CPU units."
  value       = aws_ecs_express_gateway_service.service.cpu
}

output "memory" {
  description = "ECS Express task memory in MiB."
  value       = aws_ecs_express_gateway_service.service.memory
}

output "container_port" {
  description = "Primary container port exposed by ECS Express."
  value       = aws_ecs_express_gateway_service.service.primary_container[0].container_port
}

output "health_check_path" {
  description = "HTTP path ECS Express uses for health checks."
  value       = aws_ecs_express_gateway_service.service.health_check_path
}

output "min_task_count" {
  description = "Minimum ECS Express task count."
  value       = aws_ecs_express_gateway_service.service.scaling_target[0].min_task_count
}

output "max_task_count" {
  description = "Maximum ECS Express task count."
  value       = aws_ecs_express_gateway_service.service.scaling_target[0].max_task_count
}

output "auto_scaling_metric" {
  description = "Metric used by ECS Express auto scaling."
  value       = aws_ecs_express_gateway_service.service.scaling_target[0].auto_scaling_metric
}

output "auto_scaling_target_value" {
  description = "Target value for ECS Express auto scaling."
  value       = aws_ecs_express_gateway_service.service.scaling_target[0].auto_scaling_target_value
}

output "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  value       = aws_cloudwatch_log_group.service.retention_in_days
}

output "wait_for_steady_state" {
  description = "Whether Terraform waits for ECS Express service steady state."
  value       = aws_ecs_express_gateway_service.service.wait_for_steady_state
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
