variable "aws_region" {
  description = "AWS region for the canonical ECR repository."
  type        = string
  default     = "ap-northeast-1"
}

variable "gcp_project_id" {
  description = "Existing GCP project ID prepared by infra/gcp-bootstrap/shared-project."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be a valid GCP project ID."
  }
}

variable "gcp_region" {
  description = "Default GCP region for Artifact Registry and future Cloud Run runtime resources."
  type        = string
  default     = "asia-northeast1"
}

variable "github_repository" {
  description = "GitHub owner/repository slug trusted by the shared GCP WIF provider and AWS OIDC roles."
  type        = string
  default     = "noidilin/portfolio-devops"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in OWNER/REPO form."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "stage"
}

variable "project_name" {
  description = "Project/lab name used in resource names and tags."
  type        = string
  default     = "static-site-cloud-run"
}

variable "service_name" {
  description = "Container service/image artifact name."
  type        = string
  default     = "cidr-calculator"
}

variable "github_environment" {
  description = "GitHub Environment whose approved jobs may impersonate the apply service account."
  type        = string
  default     = "lab-08-stage"
}

variable "github_wif_pool_id" {
  description = "Shared GitHub Workload Identity Federation pool ID from infra/gcp-bootstrap/shared-project."
  type        = string
  default     = "github-actions"
}

variable "github_wif_provider_id" {
  description = "Shared GitHub Workload Identity Federation provider ID from infra/gcp-bootstrap/shared-project."
  type        = string
  default     = "github"
}

variable "gcp_state_bucket_name" {
  description = "Shared GCS Terraform state bucket name from infra/gcp-bootstrap/shared-project."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]$", var.gcp_state_bucket_name))
    error_message = "gcp_state_bucket_name must be a valid GCS bucket name."
  }
}

variable "artifact_cleanup_keep_count" {
  description = "Number of recent image versions to retain in Artifact Registry."
  type        = number
  default     = 20

  validation {
    condition     = var.artifact_cleanup_keep_count > 0
    error_message = "artifact_cleanup_keep_count must be greater than zero."
  }
}

variable "labels" {
  description = "Lowercase GCP labels applied to supported bootstrap resources."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", key)) && can(regex("^[a-z0-9_-]{0,63}$", value))
    ])
    error_message = "labels must use lowercase GCP label-compatible keys and values."
  }
}

variable "tags" {
  description = "Additional AWS tags for bootstrap resources."
  type        = map(string)
  default     = {}
}
