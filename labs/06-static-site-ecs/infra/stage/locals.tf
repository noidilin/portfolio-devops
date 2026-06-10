locals {
  name_prefix = "devops-${var.project_name}-${var.environment}"

  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    Lab         = "06-static-site-ecs"
  }
}
