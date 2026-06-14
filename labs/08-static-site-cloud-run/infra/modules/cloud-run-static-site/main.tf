locals {
  cloud_run_service_name       = substr(replace("${var.name_prefix}-${var.service_name}", "_", "-"), 0, 63)
  runtime_service_account_id   = substr(replace("${var.name_prefix}-runtime", "_", "-"), 0, 30)
  runtime_service_account_name = "projects/${var.gcp_project_id}/serviceAccounts/${google_service_account.runtime.email}"
}

resource "google_service_account" "runtime" {
  project      = var.gcp_project_id
  account_id   = local.runtime_service_account_id
  display_name = "${var.name_prefix} Cloud Run runtime"
  description  = "Dedicated runtime identity for the Lab 08 Cloud Run static-site container."
}

resource "google_cloud_run_v2_service" "service" {
  project             = var.gcp_project_id
  name                = local.cloud_run_service_name
  location            = var.gcp_region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false
  labels              = var.labels

  template {
    labels          = var.labels
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = var.container_image

      ports {
        name           = "http1"
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle = true
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.gcp_project_id
  location = google_cloud_run_v2_service.service.location
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
