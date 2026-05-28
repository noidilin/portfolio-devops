resource "aws_ecr_repository" "service" {
  name                 = "${var.name_prefix}-${var.service_name}"
  image_tag_mutability = var.ecr_image_tag_mutability
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "terraform_data" "image_tag" {
  input = var.image_tag
}

resource "aws_iam_role" "instance" {
  name                 = "${var.name_prefix}-${var.service_name}-ec2"
  permissions_boundary = local.lab_permissions_boundary_arn
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "ecr_pull" {
  name        = "${var.name_prefix}-${var.service_name}-ecr-pull"
  description = "Allow the EC2 runtime host to pull images from its service ECR repository."
  policy      = data.aws_iam_policy_document.ecr_pull.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.ecr_pull.arn
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-${var.service_name}-ec2"
  role = aws_iam_role.instance.name

  tags = local.common_tags
}

resource "aws_security_group" "instance" {
  name        = "${var.name_prefix}-${var.service_name}-http"
  description = "HTTP-only public ingress for the ${var.service_name} EC2 runtime host; no SSH ingress."
  vpc_id      = data.aws_vpc.default.id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-${var.service_name}-http"
  })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.http_ingress_cidr_blocks)

  security_group_id = aws_security_group.instance.id
  description       = "Allow public HTTP ingress."
  from_port         = local.http_port
  to_port           = local.http_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.instance.id
  description       = "Allow outbound traffic for package installs, ECR pulls, and SSM connectivity."
  ip_protocol       = "-1"
  cidr_ipv4         = local.all_outbound

  tags = local.common_tags
}

resource "aws_instance" "service" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = local.selected_subnet
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  user_data = coalesce(var.user_data, templatefile("${path.module}/user-data.sh.tftpl", {
    aws_region         = data.aws_region.current.region
    ecr_repository_url = aws_ecr_repository.service.repository_url
    image_tag          = var.image_tag
    container_image    = local.container_image
    service_name       = var.service_name
  }))
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.image_tag]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-${var.service_name}"
  })

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core,
    aws_iam_role_policy_attachment.ecr_pull
  ]
}
