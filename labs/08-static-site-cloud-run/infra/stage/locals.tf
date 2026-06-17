locals {
  lab_id      = "08-static-site-cloud-run"
  name_prefix = "devops-${var.project_name}-${var.environment}"

  artifact_registry_image_base  = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${var.artifact_registry_repository_id}/${var.service_name}"
  container_image               = "${local.artifact_registry_image_base}:${var.image_tag}"
  runtime_service_account_id    = substr(replace("${local.name_prefix}-runtime", "_", "-"), 0, 30)
  runtime_service_account_email = "${local.runtime_service_account_id}@${var.gcp_project_id}.iam.gserviceaccount.com"

  default_labels = merge(var.labels, {
    project     = replace(var.project_name, "-", "_")
    environment = var.environment
    lab         = "08_cloud_run"
    managed_by  = "terraform"
    service     = replace(var.service_name, "-", "_")
  })
}
