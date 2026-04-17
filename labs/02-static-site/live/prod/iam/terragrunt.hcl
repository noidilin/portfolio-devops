include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${find_in_parent_folders("catalog/modules")}//iam"
}

dependency "s3" {
  config_path = "../s3"

  # NOTE:
  # Some providers require these inputs to be valid.
  # Using `mock_outputs` allows us to plan successfully 
  # without worrying about getting errors that required variables aren’t passed in.
  mock_outputs = {
    arn = "arn:aws:s3:::mock-bucket-name"
  }

  # By default, Terragrunt use mocked outputs whenever a dependency returns no outputs
  mock_outputs_allowed_terraform_commands = ["plan", "state"]
  # Since we are pushing existing state to units, but their outputs are also changing
  # we have to address how the state is being merged
  mock_outputs_merge_strategy_with_state  = "shallow"
}

dependency "ddb" {
  config_path = "../ddb"

  mock_outputs = {
    arn = "arn:aws:dynamodb:us-east-1:123456789012:table/mock-table-name"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "state"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  name = "break-terralith"
  aws_region = "ap-northeast-1"
  s3_bucket_arn = dependency.s3.outputs.arn
  dynamodb_table_arn = dependency.ddb.outputs.arn
}
