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

variable "image_tag" {
  description = "Explicit ECR image tag for the EC2 runtime to pull and run. Change this to replace the instance and rerun user-data."
  type        = string
  default     = "sha-0000000000000000000000000000000000000000"

  validation {
    condition     = can(regex("^[\\w][\\w.-]{0,127}$", var.image_tag))
    error_message = "image_tag must be a valid Docker tag: 1-128 chars, starting with a word char, then word chars, dots, or dashes."
  }
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


variable "user_data" {
  description = "Optional cloud-init/user-data override. Defaults to installing Docker, pulling image_tag from ECR, and running it on port 80."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all taggable resources."
  type        = map(string)
  default     = {}
}
