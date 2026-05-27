module "runtime" {
  source = "../modules/ec2-docker-runtime"

  name_prefix              = local.name_prefix
  service_name             = var.service_name
  instance_type            = var.instance_type
  subnet_id                = var.subnet_id
  http_ingress_cidr_blocks = var.http_ingress_cidr_blocks
  ecr_force_delete         = var.ecr_force_delete
  tags                     = local.default_tags
}
