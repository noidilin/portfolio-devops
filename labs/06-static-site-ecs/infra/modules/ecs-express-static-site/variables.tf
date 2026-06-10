variable "name_prefix" {
  description = "Prefix used for named AWS resources. Must satisfy this repo's lab IAM prefix rules."
  type        = string
}

variable "service_name" {
  description = "Human-readable service name used for tags, the ECR repository suffix, and the ECS Express service suffix."
  type        = string
  default     = "cidr-calculator"
}

variable "image_tag" {
  description = "Explicit ECR image tag for ECS Express Mode to deploy. Terraform does not build or infer this tag."
  type        = string
  default     = "latest"

  validation {
    condition     = can(regex("^[\\w][\\w.-]{0,127}$", var.image_tag))
    error_message = "image_tag must be a valid Docker tag: 1-128 chars, starting with a word char, then word chars, dots, or dashes."
  }
}

variable "container_port" {
  description = "Port exposed by the primary container. The static Nginx image listens on 80."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "HTTP path ECS Express Mode uses for load balancer health checks."
  type        = string
  default     = "/"
}

variable "cpu" {
  description = "Task CPU units for ECS Express Mode. Valid values are powers of 2 between 256 and 4096."
  type        = string
  default     = "256"

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.cpu)
    error_message = "cpu must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Task memory in MiB for ECS Express Mode."
  type        = string
  default     = "512"

  validation {
    condition     = contains(["512", "1024", "2048", "3072", "4096", "5120", "6144", "7168", "8192"], var.memory)
    error_message = "memory must be 512 through 8192 MiB, in 1 GiB increments after 1024."
  }
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

  validation {
    condition     = contains(["AVERAGE_CPU", "AVERAGE_MEMORY", "REQUEST_COUNT_PER_TARGET"], var.auto_scaling_metric)
    error_message = "auto_scaling_metric must be AVERAGE_CPU, AVERAGE_MEMORY, or REQUEST_COUNT_PER_TARGET."
  }
}

variable "auto_scaling_target_value" {
  description = "Target value for ECS Express Mode auto scaling."
  type        = number
  default     = 60
}

variable "subnet_ids" {
  description = "Optional subnet IDs for Express service task networking. Leave empty to let Express Mode use default networking. If set, provide at least two subnets."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.subnet_ids) == 0 || length(var.subnet_ids) >= 2
    error_message = "subnet_ids must be empty or contain at least two subnet IDs."
  }
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

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ecr_image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "ecr_force_delete" {
  description = "Allow Terraform to delete the lab ECR repository even when it contains images. Useful for disposable labs."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days for the container log group."
  type        = number
  default     = 14
}

variable "wait_for_steady_state" {
  description = "Wait for ECS Express service steady state before Terraform apply completes."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all taggable resources."
  type        = map(string)
  default     = {}
}
