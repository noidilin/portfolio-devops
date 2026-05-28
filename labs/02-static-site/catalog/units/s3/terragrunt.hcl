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
  source = "${find_in_parent_folders("catalog/modules")}//s3"
}

inputs = {
  name          = values.name
  force_destroy = try(values.force_destroy, false)
}
