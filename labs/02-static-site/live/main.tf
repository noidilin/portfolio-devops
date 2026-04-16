module "ddb" {
  source = "../catalog/modules/ddb"
  name   = var.name
}

module "s3" {
  source = "../catalog/modules/s3"
  name   = var.name
}
