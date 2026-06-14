output "instance_name" {
  description = "GCE VM instance name."
  value       = google_compute_instance.static_site.name
}

output "public_ip" {
  description = "Ephemeral public IPv4 address assigned to the GCE VM."
  value       = google_compute_instance.static_site.network_interface[0].access_config[0].nat_ip
}

output "service_url" {
  description = "Public HTTP URL for the static site."
  value       = "http://${google_compute_instance.static_site.network_interface[0].access_config[0].nat_ip}"
}

output "container_image" {
  description = "Artifact Registry image deployed by startup script."
  value       = var.container_image
}

output "runtime_service_account_email" {
  description = "Dedicated runtime service account email used by the VM."
  value       = google_service_account.runtime.email
}

output "network_name" {
  description = "Dedicated runtime VPC network name."
  value       = google_compute_network.runtime.name
}

output "subnet_name" {
  description = "Dedicated runtime subnet name."
  value       = google_compute_subnetwork.runtime.name
}

output "machine_type" {
  description = "GCE VM machine type."
  value       = var.machine_type
}

output "boot_image_family" {
  description = "Ubuntu image family configured for the VM."
  value       = var.boot_image_family
}

output "container_port" {
  description = "Container port published on public HTTP."
  value       = var.container_port
}

output "os_login_enabled" {
  description = "Whether OS Login is enabled in instance metadata."
  value       = google_compute_instance.static_site.metadata["enable-oslogin"] == "TRUE"
}

output "iap_ssh_source_ranges" {
  description = "CIDR ranges allowed to reach TCP/22 for IAP SSH forwarding."
  value       = var.iap_ssh_source_ranges
}

output "startup_script" {
  description = "Rendered startup script for syntax validation and debugging."
  value       = local.startup_script
  sensitive   = true
}
