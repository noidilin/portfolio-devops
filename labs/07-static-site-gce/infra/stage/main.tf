module "runtime" {
  source = "../modules/gce-docker-runtime"

  gcp_project_id                  = var.gcp_project_id
  gcp_region                      = var.gcp_region
  gcp_zone                        = var.gcp_zone
  name_prefix                     = local.name_prefix
  service_name                    = var.service_name
  container_image                 = local.container_image
  artifact_registry_host          = local.artifact_registry_host
  artifact_registry_repository_id = var.artifact_registry_repository_id
  container_port                  = var.container_port
  machine_type                    = var.machine_type
  boot_disk_size_gb               = var.boot_disk_size_gb
  boot_image_project              = var.boot_image_project
  boot_image_family               = var.boot_image_family
  subnet_cidr                     = var.subnet_cidr
  http_source_ranges              = var.http_source_ranges
  iap_ssh_source_ranges           = var.iap_ssh_source_ranges
  labels                          = local.default_labels
}
