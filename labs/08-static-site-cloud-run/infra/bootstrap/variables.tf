variable "aws_region" {
  description = "AWS region for the canonical ECR repository."
  type        = string
  default     = "ap-northeast-1"
}

variable "gcp_project_id" {
  description = "Existing GCP project ID prepared by infra/bootstrap/gcp."
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

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.environment))
    error_message = "environment must be 1-30 characters, lowercase, start with a letter, and contain only letters, digits, and hyphens."
  }
}

variable "project_name" {
  description = "Project/lab name used in resource names and tags."
  type        = string
  default     = "static-site-cloud-run"

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
  description = "GitHub Environment whose approved jobs may impersonate the apply service account."
  type        = string
  default     = "lab-08-stage"
}

variable "github_wif_pool_name" {
  description = "Full shared Workload Identity Federation pool name, for example projects/123/locations/global/workloadIdentityPools/github-actions."
  type        = string

  validation {
    condition     = can(regex("^projects/[0-9]+/locations/global/workloadIdentityPools/[a-z][a-z0-9-]{2,30}[a-z0-9]$", var.github_wif_pool_name))
    error_message = "github_wif_pool_name must be a full WIF pool resource name."
  }
}

variable "github_wif_provider_name" {
  description = "Full shared Workload Identity Federation provider name used by GitHub Actions authentication."
  type        = string

  validation {
    condition     = can(regex("^projects/[0-9]+/locations/global/workloadIdentityPools/[a-z][a-z0-9-]{2,30}[a-z0-9]/providers/[a-z][a-z0-9-]{2,30}[a-z0-9]$", var.github_wif_provider_name))
    error_message = "github_wif_provider_name must be a full WIF provider resource name."
  }
}

variable "gcp_state_bucket_name" {
  description = "Shared GCS Terraform state bucket name from infra/bootstrap/gcp."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]$", var.gcp_state_bucket_name))
    error_message = "gcp_state_bucket_name must be a valid GCS bucket name."
  }
}

variable "artifact_registry_keep_count" {
  description = "Number of most recent Docker image versions to retain in Artifact Registry."
  type        = number
  default     = 20

  validation {
    condition     = var.artifact_registry_keep_count > 0
    error_message = "artifact_registry_keep_count must be greater than zero."
  }
}

variable "artifact_registry_delete_older_than" {
  description = "Age threshold for deleting older SHA-tagged Artifact Registry images."
  type        = string
  default     = "2592000s"
}

variable "artifact_registry_untagged_delete_older_than" {
  description = "Age threshold for deleting untagged Artifact Registry images."
  type        = string
  default     = "86400s"
}

variable "gcp_labels" {
  description = "Additional lowercase GCP labels for bootstrap resources."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.gcp_labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", key)) && can(regex("^[a-z0-9_-]{0,63}$", value))
    ])
    error_message = "gcp_labels must use lowercase GCP label-compatible keys and values."
  }
}

variable "aws_tags" {
  description = "Additional AWS tags for bootstrap resources."
  type        = map(string)
  default     = {}
}
