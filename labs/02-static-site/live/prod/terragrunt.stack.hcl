locals {
  environment = "prod"
  name        = "break-terralith"
  aws_region  = "ap-northeast-1"
  units_path  = find_in_parent_folders("catalog/units")
}

unit "ddb" {
  source = "${local.units_path}/ddb"
  path   = "ddb"

  values = {
    environment = local.environment
    name        = local.name
    aws_region  = local.aws_region
  }
}

unit "s3" {
  source = "${local.units_path}/s3"
  path   = "s3"

  values = {
    environment   = local.environment
    name          = local.name
    aws_region    = local.aws_region
    force_destroy = true
  }
}

unit "iam" {
  source = "${local.units_path}/iam"
  path   = "iam"

  values = {
    environment = local.environment
    name        = local.name
    aws_region  = local.aws_region
    s3_path     = "../s3"
    ddb_path    = "../ddb"
  }
}

unit "lambda" {
  source = "${local.units_path}/lambda"
  path   = "lambda"

  values = {
    environment = local.environment
    name        = local.name
    aws_region  = local.aws_region
    s3_path     = "../s3"
    ddb_path    = "../ddb"
    iam_path    = "../iam"
  }
}

