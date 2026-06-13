variable "aws_region" {
  description = "AWS region for the canonical ECR repository."
  type        = string
  default     = "ap-northeast-1"
}

variable "gcp_project_id" {
  description = "Existing GCP project ID bootstrapped by infra/gcp-bootstrap/shared-project."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be a valid GCP project ID."
  }
}

variable "gcp_project_number" {
  description = "Numeric GCP project number from the shared bootstrap output."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.gcp_project_number))
    error_message = "gcp_project_number must contain digits only."
  }
}

variable "gcp_region" {
  description = "Default GCP region for Artifact Registry and future GCE runtime resources."
  type        = string
  default     = "asia-northeast1"
}

variable "github_repository" {
  description = "GitHub owner/repository slug used in WIF trust members."
  type        = string
  default     = "noidilin/portfolio-devops"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in OWNER/REPO form."
  }
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

variable "terraform_state_bucket_name" {
  description = "Shared GCS Terraform state bucket name created by the shared GCP bootstrap."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]$", var.terraform_state_bucket_name))
    error_message = "terraform_state_bucket_name must be a valid GCS bucket name."
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
  default     = "static-site-gce"
}

variable "service_name" {
  description = "Container service/image artifact name."
  type        = string
  default     = "cidr-calculator"
}

variable "github_environment" {
  description = "GitHub Environment whose approved jobs may impersonate the apply service account."
  type        = string
  default     = "lab-07-stage"
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

variable "aws_tags" {
  description = "Additional AWS tags for bootstrap resources."
  type        = map(string)
  default     = {}
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
