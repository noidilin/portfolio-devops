variable "gcp_project_id" {
  description = "GCP project ID that hosts the Cloud Run service."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for the Cloud Run service."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for Cloud Run and runtime service account resources."
  type        = string
}

variable "service_name" {
  description = "Static-site service and image artifact name."
  type        = string
}

variable "container_image" {
  description = "Fully qualified Artifact Registry image reference, including immutable tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+-docker\\.pkg\\.dev/[a-z][a-z0-9-]{4,28}[a-z0-9]/[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*:[\\w][\\w.-]{0,127}$", var.container_image))
    error_message = "container_image must be a tagged Artifact Registry image reference."
  }
}

variable "container_port" {
  description = "Container port exposed by the static-site image."
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Cloud Run CPU limit for the lab container."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Cloud Run memory limit for the lab container."
  type        = string
  default     = "256Mi"
}

variable "min_instance_count" {
  description = "Minimum Cloud Run instances. Zero keeps the lab scaled to zero while idle."
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum Cloud Run instances to guard personal lab cost."
  type        = number
  default     = 2

  validation {
    condition     = var.max_instance_count >= 1 && var.max_instance_count <= 2
    error_message = "max_instance_count must be 1 or 2 for this lab guardrail."
  }
}

variable "labels" {
  description = "Lowercase labels applied to supported GCP resources."
  type        = map(string)
  default     = {}
}
