provider "google" {
  project = var.project_id
  region  = var.default_region
  zone    = var.default_zone

  # Local ADC can carry a stale or missing quota project. Force provider calls
  # to use the bootstrapped project for quota/billing attribution, which is
  # required by APIs such as Cloud Billing Budgets.
  billing_project       = var.project_id
  user_project_override = true
}
