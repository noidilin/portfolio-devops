variable "aws_region" {
  description = "AWS region used for provider operations. IAM resources are global."
  type        = string
  default     = "ap-northeast-1"
}

variable "tags" {
  description = "Tags applied to taggable bootstrap resources."
  type        = map(string)
  default = {
    Project     = "devops-lab-cicd"
    Environment = "bootstrap"
    ManagedBy   = "terraform"
  }
}
