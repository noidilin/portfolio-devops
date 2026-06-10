module "runtime" {
  source = "../modules/ecs-express-static-site"

  name_prefix               = local.name_prefix
  service_name              = var.service_name
  image_tag                 = var.image_tag
  cpu                       = var.cpu
  memory                    = var.memory
  health_check_path         = var.health_check_path
  min_task_count            = var.min_task_count
  max_task_count            = var.max_task_count
  auto_scaling_metric       = var.auto_scaling_metric
  auto_scaling_target_value = var.auto_scaling_target_value
  subnet_ids                = var.subnet_ids
  security_group_ids        = var.security_group_ids
  ecr_image_tag_mutability  = var.ecr_image_tag_mutability
  ecr_force_delete          = var.ecr_force_delete
  log_retention_days        = var.log_retention_days
  wait_for_steady_state     = var.wait_for_steady_state
  tags                      = local.default_tags
}
