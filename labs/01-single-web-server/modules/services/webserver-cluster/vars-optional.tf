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
