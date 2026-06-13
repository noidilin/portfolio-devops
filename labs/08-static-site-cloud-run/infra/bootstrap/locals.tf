locals {
  lab_id                         = "08-static-site-cloud-run"
  name_prefix                    = "devops-${var.project_name}-${var.environment}"
  ecr_repository_name            = "${local.name_prefix}-${var.service_name}"
  artifact_repository_id         = replace(local.ecr_repository_name, "_", "-")
  github_repository_owner        = split("/", var.github_repository)[0]
  aws_oidc_provider_arn          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  permissions_boundary_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-gitops-oidc-apply-permissions-boundary"
  gcp_wif_pool_name              = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.github_wif_pool_id}"
  gcp_wif_provider_name          = "${local.gcp_wif_pool_name}/providers/${var.github_wif_provider_id}"
  gcp_plan_principal_set         = "principalSet://iam.googleapis.com/${local.gcp_wif_pool_name}/attribute.repository/${var.github_repository}"
  gcp_apply_principal            = "principal://iam.googleapis.com/${local.gcp_wif_pool_name}/subject/repo:${var.github_repository}:environment:${var.github_environment}"
  gcp_state_prefix               = "gcp/runtime/labs/${local.lab_id}/${var.environment}/"
  plan_service_account_id        = "lab-08-cloudrun-plan"
  apply_service_account_id       = "lab-08-cloudrun-apply"
  plan_custom_role_id            = "lab08CloudRunPlan"
  apply_custom_role_id           = "lab08CloudRunApply"
  bootstrap_admin_custom_role_id = "lab08CloudRunBootstrapAdmin"

  gcp_labels = merge(var.labels, {
    project     = replace(var.project_name, "-", "_")
    environment = var.environment
    lab         = "08_cloud_run"
    managed_by  = "terraform"
    service     = replace(var.service_name, "-", "_")
  })

  aws_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    Lab         = local.lab_id
    ManagedBy   = "terraform"
  })
}
