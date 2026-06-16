variable "aws_region" {
  description = "AWS region for regional bootstrap resources such as ECR."
  type        = string
  default     = "ap-northeast-1"
}

variable "github_repository" {
  description = "GitHub owner/repository slug used in OIDC trust conditions."
  type        = string
  default     = "noidilin/portfolio-devops"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be owner/repo: owner 1-39 alphanumerics/hyphens, repo alphanumerics, dots, underscores, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "stage"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.environment))
    error_message = "environment must be 1-30 characters, lowercase, start with a letter, and contain only letters, digits, and hyphens."
  }
}

variable "project_name" {
  description = "Project/lab name used in resource names and tags."
  type        = string
  default     = "static-site-ec2"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.project_name))
    error_message = "project_name must be 1-30 characters, lowercase, start with a letter, and contain only letters, digits, and hyphens."
  }
}

variable "service_name" {
  description = "Container service/image artifact name."
  type        = string
  default     = "cidr-calculator"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.service_name))
    error_message = "service_name must be 1-30 characters, lowercase, start with a letter, and contain only letters, digits, and hyphens."
  }
}

variable "github_environment" {
  description = "GitHub Environment whose approved jobs may assume the apply role."
  type        = string
  default     = "lab-05-stage"
}

variable "tags" {
  description = "Additional tags for bootstrap resources."
  type        = map(string)
  default     = {}
}
