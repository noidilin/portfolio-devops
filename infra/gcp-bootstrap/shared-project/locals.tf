locals {
  # Keep this list intentionally small. It is the shared project foundation for the
  # current GCE and Cloud Run static-site lab roadmap, not a general landing zone.
  required_project_services = toset([
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iap.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])

  github_repository_owner = split("/", var.github_repository)[0]
  state_bucket_name       = coalesce(var.state_bucket_name, "${var.project_id}-tf-state")
}
