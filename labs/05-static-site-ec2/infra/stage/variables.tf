variable "aws_region" {
  description = "AWS region for the stage deployment."
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "stage"
}

variable "project_name" {
  description = "Project/lab name used in resource names and tags."
  type        = string
  default     = "static-site-ec2"
}

variable "service_name" {
  description = "Service/image artifact name."
  type        = string
  default     = "cidr-calculator"
}

variable "instance_type" {
  description = "EC2 instance type for the Docker runtime host."
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Optional default-VPC subnet override. Leave null to use the first default subnet."
  type        = string
  default     = null
}

variable "http_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach HTTP port 80."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ecr_force_delete" {
  description = "Allow Terraform to destroy the lab ECR repository even if it contains images."
  type        = bool
  default     = false
}
