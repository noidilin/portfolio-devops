locals {
  name = "break-terralith-dev"
  aws_region = "ap-northeast-1"
  units_path = find_in_parent_folders("catalog/units")
}

unit "ddb" {
  source = "${local.units_path}/ddb"
  path = "ddb"

  no_dot_terragrunt_stack = true

  values = {
    name = local.name
  }
}

unit "s3" {
  source = "${local.units_path}/s3"
  path = "s3"

  no_dot_terragrunt_stack = true

  values = {
    name = local.name
    force_destroy = true
  }
}

unit "iam" {
  source = "${local.units_path}/iam"
  path = "iam"

  no_dot_terragrunt_stack = true

  values = {
    name = local.name
    aws_region = local.aws_region
    s3_path = "../s3"
    ddb_path = "../ddb"
  }
}

unit "lambda" {
  source = "${local.units_path}/lambda"
  path = "lambda"

  no_dot_terragrunt_stack = true
  values = {
    name = local.name
    aws_region = local.aws_region
    s3_path = "../s3"
    ddb_path = "../ddb"
    iam_path = "../iam"
  }
}

