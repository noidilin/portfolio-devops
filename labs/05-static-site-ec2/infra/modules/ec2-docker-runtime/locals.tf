locals {
  http_port       = 80
  all_outbound    = "0.0.0.0/0"
  selected_subnet = coalesce(var.subnet_id, sort(data.aws_subnets.default.ids)[0])

  common_tags = merge(
    var.tags,
    {
      Service   = var.service_name
      ManagedBy = "terraform"
    }
  )
}
