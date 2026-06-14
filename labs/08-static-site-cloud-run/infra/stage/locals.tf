locals {
  lab_id      = "08-static-site-cloud-run"
  name_prefix = "devops-${var.project_name}-${var.environment}"

  artifact_registry_image_base = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${var.artifact_registry_repository_id}/${var.service_name}"
  container_image              = "${local.artifact_registry_image_base}:${var.image_tag}"

  default_labels = merge(var.labels, {
    project     = replace(var.project_name, "-", "_")
    environment = var.environment
    lab         = "08_cloud_run"
    managed_by  = "terraform"
    service     = replace(var.service_name, "-", "_")
  })
}
