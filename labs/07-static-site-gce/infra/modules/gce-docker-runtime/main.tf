locals {
  network_name               = substr(replace("${var.name_prefix}-vpc", "_", "-"), 0, 63)
  subnet_name                = substr(replace("${var.name_prefix}-subnet", "_", "-"), 0, 63)
  vm_name                    = substr(replace("${var.name_prefix}-${var.service_name}", "_", "-"), 0, 63)
  runtime_service_account_id = substr(replace("${var.name_prefix}-runtime", "_", "-"), 0, 30)
  http_target_tag            = substr(replace("${var.name_prefix}-http", "_", "-"), 0, 63)
  iap_ssh_target_tag         = substr(replace("${var.name_prefix}-iap-ssh", "_", "-"), 0, 63)
  startup_script = templatefile("${path.module}/startup-script.sh.tftpl", {
    container_image        = var.container_image
    container_name         = var.service_name
    container_port         = var.container_port
    artifact_registry_host = var.artifact_registry_host
  })
}

data "google_compute_image" "ubuntu" {
  project = var.boot_image_project
  family  = var.boot_image_family
}

resource "terraform_data" "container_image" {
  input = var.container_image

  lifecycle {
    precondition {
      condition     = startswith(var.container_image, "${var.artifact_registry_host}/")
      error_message = "container_image registry host must match artifact_registry_host."
    }
  }
}

resource "google_compute_network" "runtime" {
  project                 = var.gcp_project_id
  name                    = local.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "runtime" {
  project                  = var.gcp_project_id
  name                     = local.subnet_name
  ip_cidr_range            = var.subnet_cidr
  region                   = var.gcp_region
  network                  = google_compute_network.runtime.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow_http" {
  project       = var.gcp_project_id
  name          = substr(replace("${var.name_prefix}-allow-http", "_", "-"), 0, 63)
  network       = google_compute_network.runtime.name
  direction     = "INGRESS"
  source_ranges = var.http_source_ranges
  target_tags   = [local.http_target_tag]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.container_port)]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  project       = var.gcp_project_id
  name          = substr(replace("${var.name_prefix}-allow-iap-ssh", "_", "-"), 0, 63)
  network       = google_compute_network.runtime.name
  direction     = "INGRESS"
  source_ranges = var.iap_ssh_source_ranges
  target_tags   = [local.iap_ssh_target_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_service_account" "runtime" {
  project      = var.gcp_project_id
  account_id   = local.runtime_service_account_id
  display_name = "${var.name_prefix} GCE runtime"
  description  = "Dedicated runtime identity for the Lab 07 GCE Docker static-site VM."
}

resource "google_artifact_registry_repository_iam_member" "artifact_registry_reader" {
  project    = var.gcp_project_id
  location   = var.gcp_region
  repository = var.artifact_registry_repository_id
  role       = "roles/artifactregistry.reader"
  member     = google_service_account.runtime.member
}

resource "google_compute_instance" "static_site" {
  project      = var.gcp_project_id
  name         = local.vm_name
  zone         = var.gcp_zone
  machine_type = var.machine_type
  tags         = [local.http_target_tag, local.iap_ssh_target_tag]
  labels       = var.labels

  boot_disk {
    auto_delete = true

    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.runtime.id

    access_config {}
  }

  metadata = {
    enable-oslogin = "TRUE"
    image-tag      = regex("[^:]+$", var.container_image)
  }

  metadata_startup_script = local.startup_script

  service_account {
    email  = google_service_account.runtime.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  allow_stopping_for_update = true

  lifecycle {
    replace_triggered_by = [terraform_data.container_image]
  }

  depends_on = [google_artifact_registry_repository_iam_member.artifact_registry_reader]
}
