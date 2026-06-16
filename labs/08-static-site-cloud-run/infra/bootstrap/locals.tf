locals {
  lab_id                   = "08-static-site-cloud-run"
  name_prefix              = "devops-${var.project_name}-${var.environment}"
  ecr_repository_name      = "${local.name_prefix}-${var.service_name}"
  artifact_repository_id   = replace(local.ecr_repository_name, "_", "-")
  github_repository_owner  = split("/", var.github_repository)[0]
  aws_oidc_provider_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-gitops-oidc-apply-permissions-boundary"
  gcp_bootstrap_prefix     = "gcp/bootstrap/labs/${local.lab_id}/"
  gcp_state_prefix         = "gcp/runtime/labs/${local.lab_id}/${var.environment}/"
  plan_service_account_id  = "devops-cloudrun-${var.environment}-plan"
  apply_service_account_id = "devops-cloudrun-${var.environment}-apply"
  plan_custom_role_id      = "lab08CloudRunPlan"
  apply_custom_role_id     = "lab08CloudRunApply"

  plan_wif_members = [
    "principal://iam.googleapis.com/${var.github_wif_pool_name}/subject/repo:${var.github_repository}:pull_request",
    "principal://iam.googleapis.com/${var.github_wif_pool_name}/subject/repo:${var.github_repository}:ref:refs/heads/main",
  ]

  apply_wif_members = [
    "principal://iam.googleapis.com/${var.github_wif_pool_name}/subject/repo:${var.github_repository}:environment:${var.github_environment}",
  ]

  gcp_labels = merge(var.gcp_labels, {
    project     = var.project_name
    environment = var.environment
    lab         = local.lab_id
    managed_by  = "terraform"
    service     = var.service_name
  })

  aws_tags = merge(var.aws_tags, {
    Project     = var.project_name
    Environment = var.environment
    Lab         = local.lab_id
    ManagedBy   = "terraform"
  })
}
