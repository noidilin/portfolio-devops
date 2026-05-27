variable "name_prefix" {
  description = "Prefix used for named AWS resources."
  type        = string
}

variable "service_name" {
  description = "Human-readable service name used for tags and the ECR repository suffix."
  type        = string
  default     = "cidr-calculator"
}

variable "instance_type" {
  description = "EC2 instance type for the Docker runtime host."
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Optional subnet ID. If omitted, the first default VPC subnet is used."
  type        = string
  default     = null
}

variable "http_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the instance on HTTP port 80."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "ecr_image_tag_mutability" {
  description = "Whether image tags in ECR are MUTABLE or IMMUTABLE."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ecr_image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "ecr_force_delete" {
  description = "Allow Terraform to delete the ECR repository even when it contains images. Useful for disposable labs."
  type        = bool
  default     = false
}

variable "user_data" {
  description = "Optional cloud-init/user-data override. Defaults to installing Docker and leaving the final app container for a later slice."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all taggable resources."
  type        = map(string)
  default     = {}
}
