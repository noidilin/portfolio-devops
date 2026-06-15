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
  description = "Fully-qualified ECR image reference that EC2 user-data pulls and runs."
  value       = "${module.runtime.ecr_repository_url}:${var.image_tag}"
}

output "docker_build_tag_push_commands" {
  description = "Example commands to build the shared CIDR Calculator app image, then tag and push it to this lab's ECR repository."
  value = [
    "docker build -t ${var.service_name}:${var.image_tag} ../../../../apps/cidr-calculator",
    "docker tag ${var.service_name}:${var.image_tag} ${module.runtime.ecr_repository_url}:${var.image_tag}",
    "docker push ${module.runtime.ecr_repository_url}:${var.image_tag}"
  ]
}

output "instance_id" {
  description = "EC2 instance ID for SSM inspection."
  value       = module.runtime.instance_id
}

output "instance_public_ip" {
  description = "Public IPv4 address of the EC2 runtime host."
  value       = module.runtime.instance_public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 runtime host."
  value       = module.runtime.instance_public_dns
}

output "service_url" {
  description = "HTTP URL for the service after a container is started on port 80."
  value       = module.runtime.service_url
}

output "ssm_start_session_command" {
  description = "Command to inspect the instance without SSH."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${module.runtime.instance_id}"
}

output "security_group_id" {
  description = "Security group allowing HTTP ingress and no SSH ingress."
  value       = module.runtime.security_group_id
}

output "instance_type" {
  description = "Lab-sized EC2 instance type used for the runtime host."
  value       = module.runtime.instance_type
}

output "root_volume_size_gb" {
  description = "Root EBS volume size in GiB for the runtime host."
  value       = module.runtime.root_volume_size_gb
}

output "root_volume_type" {
  description = "Root EBS volume type for the runtime host."
  value       = module.runtime.root_volume_type
}

output "root_volume_encrypted" {
  description = "Whether the runtime host root EBS volume is encrypted."
  value       = module.runtime.root_volume_encrypted
}

output "container_port" {
  description = "HTTP port exposed by the static-site container and EC2 security group."
  value       = module.runtime.container_port
}

output "ssh_ingress_enabled" {
  description = "Whether SSH ingress is exposed. Lab 05 inspection uses SSM Session Manager instead."
  value       = module.runtime.ssh_ingress_enabled
}
