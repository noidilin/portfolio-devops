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
  default     = "static-site-ecs"
}

variable "service_name" {
  description = "Service/image artifact name."
  type        = string
  default     = "cidr-calculator"
}

variable "image_tag" {
  description = "Explicit ECR image tag for ECS Express Mode to deploy. Change this to create a new Express service revision."
  type        = string
  default     = "latest"

  validation {
    condition     = can(regex("^[\\w][\\w.-]{0,127}$", var.image_tag))
    error_message = "image_tag must be a valid Docker tag: 1-128 chars, starting with a word char, then word chars, dots, or dashes."
  }
}

variable "cpu" {
  description = "Task CPU units for ECS Express Mode."
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Task memory in MiB for ECS Express Mode."
  type        = string
  default     = "512"
}

variable "health_check_path" {
  description = "HTTP path ECS Express Mode uses for health checks."
  type        = string
  default     = "/"
}

variable "min_task_count" {
  description = "Minimum ECS Express task count."
  type        = number
  default     = 1
}

variable "max_task_count" {
  description = "Maximum ECS Express task count."
  type        = number
  default     = 3
}

variable "auto_scaling_metric" {
  description = "Metric used by ECS Express Mode auto scaling."
  type        = string
  default     = "AVERAGE_CPU"
}

variable "auto_scaling_target_value" {
  description = "Target value for ECS Express Mode auto scaling."
  type        = number
  default     = 60
}

variable "subnet_ids" {
  description = "Optional subnet IDs for Express service task networking. Leave empty to use Express Mode default networking."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Optional security group IDs for Express service task networking. Only used when subnet_ids is set."
  type        = list(string)
  default     = []
}

variable "ecr_image_tag_mutability" {
  description = "Whether image tags in ECR are MUTABLE or IMMUTABLE."
  type        = string
  default     = "MUTABLE"
}

variable "ecr_force_delete" {
  description = "Allow Terraform to destroy the lab ECR repository even if it contains images."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days for container logs."
  type        = number
  default     = 14
}

variable "wait_for_steady_state" {
  description = "Wait for ECS Express service steady state before Terraform apply completes."
  type        = bool
  default     = true
}
