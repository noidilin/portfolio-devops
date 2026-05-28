locals {
  http_port                    = 80
  all_outbound                 = "0.0.0.0/0"
  selected_subnet              = coalesce(var.subnet_id, sort(data.aws_subnets.default.ids)[0])
  container_image              = "${aws_ecr_repository.service.repository_url}:${var.image_tag}"
  lab_permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-devops-permissions-boundary"

  common_tags = merge(
    var.tags,
    {
      Service   = var.service_name
      ManagedBy = "terraform"
    }
  )
}
