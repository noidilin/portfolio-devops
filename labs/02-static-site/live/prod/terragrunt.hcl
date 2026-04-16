remote_state {
  backend = "s3"
  generate = {
    path = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    bucket = "noidilin-tf-state"
    key    = "labs/02-static-site/live/prod/terraform.tfstate"
    region = "ap-northeast-1"

    dynamodb_table = "noidilin-tf-state-locks"
    encrypt        = true
  }
}

generate "providers" {
  path = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "ap-northeast-1"
}
EOF
}

# HACK: Those // before `best_cat` are there on purpose.
# They’re how go-getter, the library that Terragrunt uses,
# indicates that it’s working with a directory within a module source.
# This allows relative references like ../s3 to work within the best_cat module.
terraform {
    source = "../../catalog/modules//best_cat"
}

inputs = {
  name = "break-terralith"
  lambda_zip_file = "${get_repo_root()}/labs/02-static-site/dist/best-cat.zip"
}
