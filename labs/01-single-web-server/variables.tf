data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

variable "instance_name" {
  description = "Value of the EC2 instance's Name tag."
  type        = string
  default     = "tf-up-and-down-app-server"
}

variable "instance_type" {
  description = "The EC2 instance's type."
  type        = string
  default     = "t3.micro"
}

variable "server_port" {
  description = "The port on which the server will listen."
  type        = number
  default     = 8080
}
