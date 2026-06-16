variable "gcp_project_id" {
  description = "Existing GCP project ID prepared by infra/bootstrap/gcp."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be a valid GCP project ID."
  }
}

variable "gcp_region" {
  description = "GCP region for Artifact Registry and Cloud Run."
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "stage"
}

variable "project_name" {
  description = "Project/lab name used in resource names and labels."
  type        = string
  default     = "static-site-cloud-run"
}

variable "service_name" {
  description = "Service/image artifact name."
  type        = string
  default     = "cidr-calculator"
}

variable "artifact_registry_repository_id" {
  description = "Artifact Registry Docker repository ID created by the Lab 08 bootstrap root."
  type        = string
  default     = "devops-static-site-cloud-run-stage-cidr-calculator"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,126}[a-z0-9]$", var.artifact_registry_repository_id))
    error_message = "artifact_registry_repository_id must be a valid Artifact Registry repository ID."
  }
}

variable "image_tag" {
  description = "Explicit immutable Artifact Registry image tag to deploy. Terraform does not build or infer this tag."
  type        = string
  default     = "sha-0000000000000000000000000000000000000000"

  validation {
    condition     = can(regex("^sha-[0-9a-f]{40}$", var.image_tag))
    error_message = "image_tag must be an immutable git SHA tag such as sha-0123456789abcdef0123456789abcdef01234567."
  }
}

variable "container_port" {
  description = "Container port exposed by the static-site image. Keep this at 80 to reuse the shared Nginx image."
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Small lab-sized Cloud Run CPU limit."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Small lab-sized Cloud Run memory limit."
  type        = string
  default     = "256Mi"
}

variable "min_instance_count" {
  description = "Minimum Cloud Run instances. Zero enables scale-to-zero."
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum Cloud Run instances for lab cost guardrails."
  type        = number
  default     = 2

  validation {
    condition     = var.max_instance_count >= 1 && var.max_instance_count <= 2
    error_message = "max_instance_count must be 1 or 2 for this lab guardrail."
  }
}

variable "labels" {
  description = "Additional lowercase GCP labels for supported runtime resources."
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
