resource "aws_launch_template" "web_launch_template" {
  name_prefix            = "single-web-server-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_instance_sg.id]

  # manage the BASH script in a separate template file with dedicate API
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }))

  update_default_version = true

  # WARN: launch configuration is immutable
  # terraform will create new configuration everytime when it changed
  # while the asg still reference to the old configuration
  # Therefore, we don't need the field `user_data_replace_on_change`
  # in launch configuration
  lifecycle {
    # make sure terraform:
    # create the replacement resource -> update existing reference
    # before it delete the old reference
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_asg" {
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = aws_launch_template.web_launch_template.latest_version
  }

  # in ASG, instances are launched and terminated all the time
  # instead of letting other services to keep tracking the instances,
  # we should associate new instance with the target group within ASG
  target_group_arns = [aws_lb_target_group.web_target_group.arn]

  # default is EC2, which only checks if the VM is completely down
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "single-web-server-asg-instance"
    propagate_at_launch = true
  }
}

# The ALB itself in different subnet under default VPC
resource "aws_lb" "web_alb" {
  name               = "single-web-server-${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.web_alb_sg.id]
}

# configure ALB to listen on the default port of HTTP
resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "web_target_group" {
  name     = "single-web-server-${var.cluster_name}-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  # sending HTTP request periodically to check if instance is healthy
  # status 200 is considered healthy
  # traffic won't be sent to unhealthy group to minimize harm
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "web_http_rule" {
  listener_arn = aws_lb_listener.web_http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

# WARN: avoid this bad practice
# - default VPC are public subnet and will be a security risk
# - use 'reverse proxies' and 'load balancers' as the gate
resource "aws_security_group" "web_instance_sg" {
  name = "single-web-server-${var.cluster_name}-instance-sg"
}

resource "aws_vpc_security_group_ingress_rule" "web_instance_allow_server_port" {
  security_group_id = aws_security_group.web_instance_sg.id

  from_port   = var.server_port
  to_port     = var.server_port
  ip_protocol = local.tcp_protocol
  cidr_ipv4   = local.all_ips
}

resource "aws_security_group" "web_alb_sg" {
  name = "single-web-server-${var.cluster_name}-alb-sg"
}

# allow inbound HTTP requests
resource "aws_vpc_security_group_ingress_rule" "web_alg_allow_http_inbound" {
  security_group_id = aws_security_group.web_alb_sg.id

  from_port   = local.http_port
  to_port     = local.http_port
  ip_protocol = local.tcp_protocol
  cidr_ipv4   = local.all_ips
}

# allow all outbound requests
resource "aws_vpc_security_group_egress_rule" "web_alb_allow_all_outbound" {
  security_group_id = aws_security_group.web_alb_sg.id

  ip_protocol = local.any_protocol
  cidr_ipv4   = local.all_ips
}
