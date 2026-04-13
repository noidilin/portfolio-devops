provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_server_instance.id]

  tags = {
    Name = var.instance_name
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  # tf will terminate the original instance and launch a totally new one when user data changed
  user_data_replace_on_change = true
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
