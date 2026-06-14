variable "gcp_project_id" {
  description = "GCP project ID that hosts the GCE runtime."
  type        = string
}

variable "gcp_region" {
  description = "GCP region for the dedicated VPC subnet."
  type        = string
}

variable "gcp_zone" {
  description = "GCP zone for the single runtime VM."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for runtime resource names."
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
    condition     = can(regex("^[a-z0-9-]+-docker\\.pkg\\.dev/[a-z][a-z0-9-]{4,28}[a-z0-9]/[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*:sha-[0-9a-f]{40}$", var.container_image))
    error_message = "container_image must be a tagged Artifact Registry image reference with an immutable sha-<40 hex> tag."
  }
}

variable "artifact_registry_host" {
  description = "Artifact Registry Docker hostname, for example asia-northeast1-docker.pkg.dev."
  type        = string
}

variable "container_port" {
  description = "Container port exposed by the static-site image."
  type        = number
  default     = 80
}

variable "machine_type" {
  description = "GCE machine type for the lab VM."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GiB."
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
  description = "Source CIDR ranges for IAP TCP forwarding to SSH."
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

variable "labels" {
  description = "Lowercase labels applied to supported GCP resources."
  type        = map(string)
  default     = {}
}
