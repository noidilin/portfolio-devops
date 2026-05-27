terraform {
  # Backend settings live in backend.hcl, loaded during terraform init:
  # terraform init -backend-config=backend.hcl
  backend "s3" {}
}
