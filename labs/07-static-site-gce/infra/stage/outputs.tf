output "artifact_registry_image_base" {
  description = "Base Artifact Registry image path. The deployed tag is appended separately."
  value       = local.artifact_registry_image_base
}

output "container_image" {
  description = "Fully-qualified Artifact Registry image reference deployed by the VM startup script."
  value       = module.runtime.container_image
}

output "instance_name" {
  description = "GCE VM instance name."
  value       = module.runtime.instance_name
}

output "public_ip" {
  description = "Public IPv4 address assigned to the static-site VM."
  value       = module.runtime.public_ip
}

output "service_url" {
  description = "Public HTTP URL for the static site."
  value       = module.runtime.service_url
}

output "runtime_service_account_email" {
  description = "Dedicated runtime service account email used by the VM."
  value       = module.runtime.runtime_service_account_email
}

output "network_name" {
  description = "Dedicated runtime VPC network name."
  value       = module.runtime.network_name
}

output "subnet_name" {
  description = "Dedicated runtime subnet name."
  value       = module.runtime.subnet_name
}

output "machine_type" {
  description = "GCE VM machine type."
  value       = module.runtime.machine_type
}

output "boot_image_family" {
  description = "Ubuntu image family configured for the VM."
  value       = module.runtime.boot_image_family
}

output "container_port" {
  description = "Container port published on public HTTP."
  value       = module.runtime.container_port
}

output "os_login_enabled" {
  description = "Whether OS Login is enabled in VM metadata."
  value       = module.runtime.os_login_enabled
}

output "iap_ssh_source_ranges" {
  description = "CIDR ranges allowed to reach TCP/22 for IAP SSH forwarding."
  value       = module.runtime.iap_ssh_source_ranges
}

output "docker_mirror_commands" {
  description = "Example commands to mirror an already-pushed ECR image tag into Lab 07 Artifact Registry. Replace the ECR URL before running."
  value = [
    "docker pull REPLACE_WITH_ECR_REPOSITORY_URL:${var.image_tag}",
    "docker tag REPLACE_WITH_ECR_REPOSITORY_URL:${var.image_tag} ${local.container_image}",
    "gcloud auth configure-docker ${local.artifact_registry_host} --project ${var.gcp_project_id}",
    "docker push ${local.container_image}"
  ]
}

output "smoke_test_command" {
  description = "Command to verify the deployed static site returns the expected HTML."
  value       = "curl -fsS http://${module.runtime.public_ip} | grep -F 'CIDR Calculator'"
}

output "iap_ssh_command" {
  description = "Command to debug the VM through IAP and OS Login without public SSH ingress."
  value       = "gcloud compute ssh ${module.runtime.instance_name} --project ${var.gcp_project_id} --zone ${var.gcp_zone} --tunnel-through-iap"
}

output "serial_port_logs_command" {
  description = "Command to inspect startup-script logs from VM serial port output."
  value       = "gcloud compute instances get-serial-port-output ${module.runtime.instance_name} --project ${var.gcp_project_id} --zone ${var.gcp_zone} --port 1"
}

output "docker_status_command" {
  description = "Command to run after IAP SSH for container and Docker service status."
  value       = "sudo systemctl status docker --no-pager && sudo docker ps --filter name=${var.service_name} && sudo docker logs ${var.service_name} --tail 100"
}

output "startup_script" {
  description = "Rendered startup script for syntax validation and debugging."
  value       = module.runtime.startup_script
  sensitive   = true
}
