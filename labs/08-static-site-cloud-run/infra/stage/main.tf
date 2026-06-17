module "runtime" {
  source = "../modules/cloud-run-static-site"

  gcp_project_id                = var.gcp_project_id
  gcp_region                    = var.gcp_region
  name_prefix                   = local.name_prefix
  service_name                  = var.service_name
  container_image               = local.container_image
  runtime_service_account_email = local.runtime_service_account_email
  container_port                = var.container_port
  cpu                           = var.cpu
  memory                        = var.memory
  min_instance_count            = var.min_instance_count
  max_instance_count            = var.max_instance_count
  labels                        = local.default_labels
}
