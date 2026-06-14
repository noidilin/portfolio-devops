locals {
  lab_id                   = "07-static-site-gce"
  name_prefix              = "devops-${var.project_name}-${var.environment}"
  ecr_repository_name      = "${local.name_prefix}-${var.service_name}"
  artifact_repository_id   = replace(local.ecr_repository_name, "_", "-")
  plan_service_account_id  = "devops-gce-${var.environment}-plan"
  apply_service_account_id = "devops-gce-${var.environment}-apply"
  plan_role_id             = "lab07GcePlan"
  apply_role_id            = "lab07GceApply"
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-gitops-oidc-apply-permissions-boundary"
  gcp_state_prefix         = "gcp/runtime/labs/${local.lab_id}/${var.environment}/"

  plan_wif_members = [
    "principal://iam.googleapis.com/${var.github_wif_pool_name}/subject/repo:${var.github_repository}:pull_request",
    "principal://iam.googleapis.com/${var.github_wif_pool_name}/subject/repo:${var.github_repository}:ref:refs/heads/main",
  ]

  apply_wif_members = [
    "principal://iam.googleapis.com/${var.github_wif_pool_name}/subject/repo:${var.github_repository}:environment:${var.github_environment}",
  ]

  plan_permissions = [
    "artifactregistry.repositories.get",
    "artifactregistry.repositories.getIamPolicy",
    "artifactregistry.repositories.list",
    "artifactregistry.tags.get",
    "artifactregistry.tags.list",
    "artifactregistry.versions.get",
    "artifactregistry.versions.list",
    "compute.firewalls.get",
    "compute.firewalls.list",
    "compute.images.get",
    "compute.images.list",
    "compute.machineTypes.get",
    "compute.networks.get",
    "compute.networks.list",
    "compute.projects.get",
    "compute.regions.get",
    "compute.subnetworks.get",
    "compute.subnetworks.list",
    "compute.zones.get",
    "iam.roles.get",
    "iam.roles.list",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.list",
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.objects.get",
    "storage.objects.list",
  ]

  apply_permissions = distinct(concat(local.plan_permissions, [
    "artifactregistry.repositories.create",
    "artifactregistry.repositories.delete",
    "artifactregistry.repositories.downloadArtifacts",
    "artifactregistry.repositories.setIamPolicy",
    "artifactregistry.repositories.update",
    "artifactregistry.repositories.uploadArtifacts",
    "artifactregistry.tags.create",
    "artifactregistry.tags.delete",
    "artifactregistry.tags.update",
    "artifactregistry.versions.delete",
    "compute.disks.create",
    "compute.disks.delete",
    "compute.disks.setLabels",
    "compute.firewalls.create",
    "compute.firewalls.delete",
    "compute.firewalls.update",
    "compute.instances.create",
    "compute.instances.delete",
    "compute.instances.get",
    "compute.instances.list",
    "compute.instances.setLabels",
    "compute.instances.setMetadata",
    "compute.instances.setServiceAccount",
    "compute.instances.setTags",
    "compute.networks.create",
    "compute.networks.delete",
    "compute.networks.updatePolicy",
    "compute.subnetworks.create",
    "compute.subnetworks.delete",
    "compute.subnetworks.use",
    "compute.subnetworks.useExternalIp",
    "iam.serviceAccounts.actAs",
    "iam.serviceAccounts.create",
    "iam.serviceAccounts.delete",
    "iam.serviceAccounts.setIamPolicy",
    "iam.serviceAccounts.update",
    "resourcemanager.projects.setIamPolicy",
    "storage.buckets.setIamPolicy",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.update",
  ]))

  aws_tags = merge(var.aws_tags, {
    Project     = var.project_name
    Environment = var.environment
    Lab         = local.lab_id
    ManagedBy   = "terraform"
  })

  gcp_labels = merge(var.gcp_labels, {
    project     = "devops-lab"
    environment = var.environment
    lab         = "07-static-site-gce"
    managed_by  = "terraform"
    service     = var.service_name
  })
}
