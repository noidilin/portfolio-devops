remote_state {
  backend = "s3"
  generate = {
    path = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    bucket = "noidilin-tf-state"
    key    = "${get_path_from_repo_root()}/terraform.tfstate"
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
