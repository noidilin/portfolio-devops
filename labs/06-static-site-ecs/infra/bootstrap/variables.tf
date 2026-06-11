variable "aws_region" {
  description = "AWS region for regional bootstrap resources such as ECR."
  type        = string
  default     = "ap-northeast-1"
}

variable "github_repository" {
  description = "GitHub owner/repository slug used in OIDC trust conditions."
  type        = string
  default     = "noidilin/portfolio-devops"
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
  description = "Container service/image artifact name."
  type        = string
  default     = "cidr-calculator"
}

variable "github_environment" {
  description = "GitHub Environment whose approved jobs may assume the apply role."
  type        = string
  default     = "lab-06-stage"
}

variable "tags" {
  description = "Additional tags for bootstrap resources."
  type        = map(string)
  default     = {}
}
