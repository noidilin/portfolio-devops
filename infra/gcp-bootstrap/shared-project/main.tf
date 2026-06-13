data "google_project" "current" {
  project_id = var.project_id

  depends_on = [
    google_project_service.required,
  ]
}

resource "google_project_service" "required" {
  for_each = local.required_project_services

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_storage_bucket" "terraform_state" {
  project = var.project_id
  name    = local.state_bucket_name

  location                    = var.state_bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    google_project_service.required["storage.googleapis.com"],
  ]
}

resource "google_billing_budget" "monthly_lab_guardrail" {
  billing_account = var.billing_account_id
  display_name    = "${var.project_id} monthly lab guardrail"

  budget_filter {
    calendar_period = "MONTH"
    projects        = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount_units)
      nanos         = var.budget_amount_nanos
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  # No pubsub_topic or monitoring channels are configured: Budget alerts use
  # the billing account's default IAM recipients.
  depends_on = [
    google_project_service.required["billingbudgets.googleapis.com"],
  ]
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.github_wif_pool_id

  display_name = "GitHub Actions"
  description  = "Shared GitHub Actions identity pool for ${var.github_repository}."
  disabled     = false

  depends_on = [
    google_project_service.required["iam.googleapis.com"],
  ]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.github_wif_provider_id

  display_name = "GitHub repository"
  description  = "Accepts GitHub OIDC tokens only from ${var.github_repository}."
  disabled     = false

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.aud"              = "assertion.aud"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.workflow"         = "assertion.workflow"
  }

  attribute_condition = "assertion.repository == '${var.github_repository}' && assertion.repository_owner == '${local.github_repository_owner}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
