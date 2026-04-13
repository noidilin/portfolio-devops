provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_launch_configuration" "app_server" {
  image_id        = data.aws_ami.ubuntu.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.app_server_instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

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

resource "aws_autoscaling_group" "app_server" {
  launch_configuration = aws_launch_configuration.app_server.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "tf-up-and-down-app-server-asg"
    propagate_at_launch = true
  }
}

# WARN: avoid this bad practice
# - default VPC are public subnet and will be a security risk
# - use 'reverse proxies' and 'load balancers' as the gate
resource "aws_security_group" "app_server_instance" {
  name = "tf-up-and-down-app-server-instance"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
