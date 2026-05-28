include "root" {
  path = find_in_parent_folders("root.hcl")
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    bucket       = "noidilin-tf-state"
    key          = "labs/02-static-site/live/${values.environment}/${basename(get_terragrunt_dir())}/terraform.tfstate"
    region       = values.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

terraform {
  source = "${find_in_parent_folders("catalog/modules")}//iam"
}

dependency "s3" {
  config_path = values.s3_path

  mock_outputs = {
    arn = "arn:aws:s3:::mock-bucket-name"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "state", "import"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "ddb" {
  config_path = values.ddb_path

  mock_outputs = {
    arn = "arn:aws:dynamodb:us-east-1:123456789012:table/mock-table-name"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "state", "import"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  name               = values.name
  aws_region         = values.aws_region
  s3_bucket_arn      = dependency.s3.outputs.arn
  dynamodb_table_arn = dependency.ddb.outputs.arn
}
