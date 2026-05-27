locals {
  name_prefix = "${var.environment}-${var.project_name}"

  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    Lab         = "05-static-site-ec2"
  }
}
