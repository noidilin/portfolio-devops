output "ecr_repository_name" {
  description = "Name of the ECR repository for the service image."
  value       = aws_ecr_repository.service.name
}

output "ecr_repository_url" {
  description = "Repository URL to use when tagging and pushing Docker images."
  value       = aws_ecr_repository.service.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.service.arn
}

output "instance_id" {
  description = "ID of the EC2 runtime host."
  value       = aws_instance.service.id
}

output "instance_public_ip" {
  description = "Public IPv4 address of the EC2 runtime host."
  value       = aws_instance.service.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 runtime host."
  value       = aws_instance.service.public_dns
}

output "service_url" {
  description = "HTTP URL for the deployed service once a container is listening on port 80."
  value       = "http://${aws_instance.service.public_dns}"
}

output "security_group_id" {
  description = "Security group attached to the EC2 runtime host."
  value       = aws_security_group.instance.id
}

output "iam_role_name" {
  description = "IAM role attached to the EC2 runtime host through its instance profile."
  value       = aws_iam_role.instance.name
}

output "subnet_id" {
  description = "Subnet selected for the EC2 runtime host."
  value       = local.selected_subnet
}
