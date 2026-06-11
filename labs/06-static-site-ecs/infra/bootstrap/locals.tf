locals {
  name_prefix              = "devops-${var.project_name}-${var.environment}"
  ecr_repository_name      = "${local.name_prefix}-${var.service_name}"
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-gitops-oidc-apply-permissions-boundary"
  state_bucket             = "noidilin-tf-state"
  state_prefix             = "labs/06-static-site-ecs/"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    Lab         = "06-static-site-ecs"
    ManagedBy   = "terraform"
  })
}
