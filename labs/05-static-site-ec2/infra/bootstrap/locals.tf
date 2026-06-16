locals {
  name_prefix              = "devops-${var.project_name}-${var.environment}"
  ecr_repository_name      = "${local.name_prefix}-${var.service_name}"
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-gitops-oidc-apply-permissions-boundary"
  state_bucket             = "noidilin-tf-state"
  # Runtime CI roles are scoped to the disposable stage state only, never the
  # human/operator-managed bootstrap state. Keys mirror infra/stage/backend.hcl.example.
  stage_state_prefix   = "labs/05-static-site-ec2/infra/stage/"
  stage_state_key      = "${local.stage_state_prefix}terraform.tfstate"
  stage_state_lock_key = "${local.stage_state_key}.tflock"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    Lab         = "05-static-site-ec2"
    ManagedBy   = "terraform"
  })
}
