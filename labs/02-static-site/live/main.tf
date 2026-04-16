module "ddb" {
  source = "../catalog/modules/ddb"
  name   = var.name
}

module "s3" {
  source = "../catalog/modules/s3"
  name   = var.name
}

module "iam" {
  source             = "../catalog/modules/iam"
  name               = var.name
  aws_region         = var.aws_region
  s3_bucket_arn      = module.s3.arn
  dynamodb_table_arn = module.ddb.arn
}
