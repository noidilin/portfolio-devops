variable "gcp_project_id" {
  description = "Existing GCP project ID prepared by infra/gcp-bootstrap/shared-project."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be a valid GCP project ID."
  }
}

variable "gcp_region" {
  description = "GCP region for Artifact Registry and the dedicated subnet."
  type        = string
  default     = "asia-northeast1"
}

variable "gcp_zone" {
  description = "GCP zone for the single GCE runtime VM."
  type        = string
  default     = "asia-northeast1-a"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "stage"
}

variable "project_name" {
  description = "Project/lab name used in resource names and labels."
  type        = string
  default     = "static-site-gce"
}

variable "service_name" {
  description = "Service/image artifact name."
  type        = string
  default     = "cidr-calculator"
}

variable "artifact_registry_repository_id" {
  description = "Artifact Registry Docker repository ID created by the Lab 07 bootstrap root."
  type        = string
  default     = "devops-static-site-gce-stage-cidr-calculator"

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

variable "machine_type" {
  description = "Small lab-sized GCE VM shape."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size_gb" {
  description = "Auto-delete boot disk size in GiB."
  type        = number
  default     = 10
}

variable "boot_image_project" {
  description = "GCP image project containing Ubuntu 24.04 LTS images."
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "boot_image_family" {
  description = "GCP image family for Ubuntu 24.04 LTS."
  type        = string
  default     = "ubuntu-2404-lts-amd64"
}

variable "subnet_cidr" {
  description = "CIDR range for the dedicated runtime subnet."
  type        = string
  default     = "10.70.0.0/24"
}

variable "http_source_ranges" {
  description = "Source CIDR ranges allowed to reach public HTTP on the VM."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "iap_ssh_source_ranges" {
  description = "IAP TCP forwarding CIDR ranges allowed to reach SSH. No public SSH range is created."
  type        = list(string)
  default     = ["35.235.240.0/20"]
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
