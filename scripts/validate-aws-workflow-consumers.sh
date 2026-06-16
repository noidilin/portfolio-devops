#!/usr/bin/env bash
set -euo pipefail

workflows=(
  ".github/workflows/aws-bootstrap-ci.yml"
  ".github/workflows/ec2-ecs-ci.yml"
  ".github/workflows/ec2-ecs-deploy.yml"
  ".github/workflows/ec2-ecs-destroy.yml"
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
    echo "Rejected legacy AWS workflow consumer pattern matched: ${pattern}" >&2
    return 1
  fi
}

# AWS bootstrap CI should cover the shared account OIDC provider root and the
# durable per-lab bootstrap roots that produce workflow-consumed ECR/role outputs.
require_text 'infra/bootstrap/aws' '.github/workflows/aws-bootstrap-ci.yml'
require_text 'labs/05-static-site-ec2/infra/bootstrap' '.github/workflows/aws-bootstrap-ci.yml'
require_text 'labs/06-static-site-ecs/infra/bootstrap' '.github/workflows/aws-bootstrap-ci.yml'

# Lab CI/deploy/destroy workflows must keep consuming the canonical role names
# and runtime state keys produced/documented by the AWS bootstrap roots.
for file in \
  '.github/workflows/ec2-ecs-ci.yml' \
  '.github/workflows/ec2-ecs-deploy.yml'; do
  require_text 'arn:aws:iam::549475122024:role/devops-static-site-ec2-stage-github-plan' "$file"
  require_text 'arn:aws:iam::549475122024:role/devops-static-site-ecs-stage-github-plan' "$file"
done

for file in \
  '.github/workflows/ec2-ecs-deploy.yml' \
  '.github/workflows/ec2-ecs-destroy.yml'; do
  require_text 'arn:aws:iam::549475122024:role/devops-static-site-ec2-stage-github-apply' "$file"
  require_text 'arn:aws:iam::549475122024:role/devops-static-site-ecs-stage-github-apply' "$file"
  require_text 'labs/05-static-site-ec2/infra/stage/terraform.tfstate' "$file"
  require_text 'labs/06-static-site-ecs/infra/stage/terraform.tfstate' "$file"
done

require_text 'arn:aws:iam::549475122024:role/devops-static-site-ec2-stage-github-image-push' '.github/workflows/ec2-ecs-deploy.yml'
require_text 'arn:aws:iam::549475122024:role/devops-static-site-ecs-stage-github-image-push' '.github/workflows/ec2-ecs-deploy.yml'
require_text 'devops-static-site-ec2-stage-cidr-calculator' '.github/workflows/ec2-ecs-deploy.yml'
require_text 'devops-static-site-ecs-stage-cidr-calculator' '.github/workflows/ec2-ecs-deploy.yml'

# Guard against the old shared-bootstrap path and any stale lab naming variants.
reject_pattern 'infra/account-bootstrap|lab-05-ec2|lab-06-ecs|github-(deploy|runtime)' "${workflows[@]}"
