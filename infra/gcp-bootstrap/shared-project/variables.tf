variable "project_id" {
  description = "ID of the existing, billing-linked GCP project to bootstrap. Terraform does not create this project."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID."
  }
}

variable "billing_account_id" {
  description = "Billing account ID that is already linked to the project, for example 000000-000000-000000."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}-[A-Fa-f0-9]{6}$", var.billing_account_id))
    error_message = "billing_account_id must look like 000000-000000-000000."
  }
}

variable "github_repository" {
  description = "GitHub repository allowed to use the shared Workload Identity Federation provider, in OWNER/REPO form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in OWNER/REPO form."
  }
}

variable "default_region" {
  description = "Default GCP region used by shared bootstrap outputs and later lab roots."
  type        = string
  default     = "asia-northeast1"
}

variable "default_zone" {
  description = "Default GCP zone used by shared bootstrap outputs and later lab roots."
  type        = string
  default     = "asia-northeast1-a"
}

variable "state_bucket_name" {
  description = "Optional explicit Terraform state bucket name. Defaults to <project_id>-tf-state."
  type        = string
  default     = null

  validation {
    condition     = var.state_bucket_name == null || can(regex("^[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid GCS bucket name."
  }
}

variable "state_bucket_location" {
  description = "Regional location for the shared Terraform state bucket."
  type        = string
  default     = "asia-northeast1"
}

variable "budget_amount_units" {
  description = "Whole currency units for the monthly budget alert. Use 10 with USD or a local-currency equivalent."
  type        = number
  default     = 10

  validation {
    condition     = var.budget_amount_units > 0
    error_message = "budget_amount_units must be greater than zero."
  }
}

variable "budget_amount_nanos" {
  description = "Fractional currency nanos for the monthly budget alert. Usually 0."
  type        = number
  default     = 0

  validation {
    condition     = var.budget_amount_nanos >= 0 && var.budget_amount_nanos < 1000000000
    error_message = "budget_amount_nanos must be between 0 and 999999999."
  }
}

variable "budget_currency" {
  description = "ISO 4217 currency code for the budget amount. Must match the billing account currency."
  type        = string
  default     = "USD"

  validation {
    condition     = can(regex("^[A-Z]{3}$", var.budget_currency))
    error_message = "budget_currency must be a three-letter ISO 4217 code."
  }
}

variable "github_wif_pool_id" {
  description = "Workload Identity Federation pool ID for GitHub Actions."
  type        = string
  default     = "github-actions"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}[a-z0-9]$", var.github_wif_pool_id))
    error_message = "github_wif_pool_id must be 4-32 lowercase letters, digits, or hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "github_wif_provider_id" {
  description = "Workload Identity Federation provider ID for GitHub Actions."
  type        = string
  default     = "github"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}[a-z0-9]$", var.github_wif_provider_id))
    error_message = "github_wif_provider_id must be 4-32 lowercase letters, digits, or hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "labels" {
  description = "Lowercase GCP labels applied to supported bootstrap resources."
  type        = map(string)
  default = {
    project     = "devops-lab"
    environment = "bootstrap"
    managed_by  = "terraform"
    service     = "shared-foundation"
    lab         = "shared"
  }

  validation {
    condition = alltrue([
      for key, value in var.labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", key)) && can(regex("^[a-z0-9_-]{0,63}$", value))
    ])
    error_message = "labels must use lowercase GCP label-compatible keys and values."
  }
}
