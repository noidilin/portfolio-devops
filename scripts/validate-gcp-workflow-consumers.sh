#!/usr/bin/env bash
set -euo pipefail

workflows=(
  ".github/workflows/gcp-bootstrap-ci.yml"
  ".github/workflows/gcp-runtime-ci.yml"
  ".github/workflows/gcp-cloud-run-deploy.yml"
  ".github/workflows/gcp-runtime-destroy.yml"
)

require_text() {
  local text=$1
  local file=$2
  if ! grep -Fq -- "$text" "$file"; then
    echo "Missing required text in ${file}: ${text}" >&2
    return 1
  fi
}

reject_pattern() {
  local pattern=$1
  shift
  if grep -En -- "$pattern" "$@"; then
    echo "Rejected legacy workflow consumer pattern matched: ${pattern}" >&2
    return 1
  fi
}

# Bootstrap CI should pass canonical Lab 07/08 Terraform variable names and full
# Workload Identity Federation resource names, not lab-specific aliases or IDs.
require_text 'gcp_state_bucket_name' '.github/workflows/gcp-bootstrap-ci.yml'
require_text 'github_wif_pool_name' '.github/workflows/gcp-bootstrap-ci.yml'
require_text 'github_wif_provider_name' '.github/workflows/gcp-bootstrap-ci.yml'
require_text 'GCP_WIF_POOL: projects/993692022673/locations/global/workloadIdentityPools/github-actions' '.github/workflows/gcp-bootstrap-ci.yml'
require_text 'GCP_WIF_PROVIDER: projects/993692022673/locations/global/workloadIdentityPools/github-actions/providers/github' '.github/workflows/gcp-bootstrap-ci.yml'

# Lab 08 workflow consumers must use the canonical Cloud Run service accounts.
for file in \
  '.github/workflows/gcp-bootstrap-ci.yml' \
  '.github/workflows/gcp-runtime-ci.yml' \
  '.github/workflows/gcp-cloud-run-deploy.yml'; do
  require_text 'devops-cloudrun-stage-plan@portfolio-devops-labs.iam.gserviceaccount.com' "$file"
done

for file in \
  '.github/workflows/gcp-cloud-run-deploy.yml' \
  '.github/workflows/gcp-runtime-destroy.yml'; do
  require_text 'devops-cloudrun-stage-apply@portfolio-devops-labs.iam.gserviceaccount.com' "$file"
done

reject_pattern 'terraform_state_bucket_name|github_wif_(pool|provider)_id|GCP_WIF_(POOL|PROVIDER)_ID|lab-08-cloudrun|artifact_cleanup_' "${workflows[@]}"
