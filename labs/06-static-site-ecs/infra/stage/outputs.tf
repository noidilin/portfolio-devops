output "ecr_repository_name" {
  description = "ECR repository name for the CIDR calculator image."
  value       = module.runtime.ecr_repository_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for docker tag/push."
  value       = module.runtime.ecr_repository_url
}

output "docker_login_command" {
  description = "Command to authenticate Docker to this account's ECR registry."
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", module.runtime.ecr_repository_url)[0]}"
}

output "container_image" {
  description = "Fully-qualified ECR image reference deployed by ECS Express Mode."
  value       = module.runtime.container_image
}

output "docker_build_tag_push_commands" {
  description = "Example commands to build, tag, and push the configured CIDR calculator image from the lab root."
  value = [
    "docker build -t ${var.service_name}:${var.image_tag} .",
    "docker tag ${var.service_name}:${var.image_tag} ${module.runtime.ecr_repository_url}:${var.image_tag}",
    "docker push ${module.runtime.ecr_repository_url}:${var.image_tag}"
  ]
}

output "ecs_cluster_name" {
  description = "ECS cluster name used by the Express service."
  value       = module.runtime.ecs_cluster_name
}

output "express_service_name" {
  description = "ECS Express Gateway service name."
  value       = module.runtime.express_service_name
}

output "express_service_arn" {
  description = "ECS Express Gateway service ARN."
  value       = module.runtime.express_service_arn
}

output "express_service_revision_arn" {
  description = "Current ECS Express service revision ARN."
  value       = module.runtime.express_service_revision_arn
}

output "ingress_paths" {
  description = "Ingress endpoints exposed by ECS Express Mode."
  value       = module.runtime.ingress_paths
}

output "service_url" {
  description = "Primary HTTPS URL exposed by ECS Express Mode."
  value       = module.runtime.service_url
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group receiving container stdout/stderr."
  value       = module.runtime.cloudwatch_log_group_name
}

output "describe_express_service_command" {
  description = "Command to inspect the ECS Express Gateway service."
  value       = "aws ecs describe-express-gateway-service --region ${var.aws_region} --service-arn ${module.runtime.express_service_arn}"
}

output "monitor_express_service_command" {
  description = "Command to monitor the ECS Express Gateway service."
  value       = "aws ecs monitor-express-gateway-service --region ${var.aws_region} --service-arn ${module.runtime.express_service_arn}"
}
