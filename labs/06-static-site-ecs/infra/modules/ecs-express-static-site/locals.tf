locals {
  common_tags = merge(var.tags, {
    Service = var.service_name
  })

  lab_permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lab-devops-permissions-boundary"
  container_image              = "${aws_ecr_repository.service.repository_url}:${var.image_tag}"
}
