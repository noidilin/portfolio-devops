output "app_server_hostname" {
  description = "Public instance name of the App Server EC2 instance."
  value       = aws_instance.app_server.public_dns
}

output "app_server_public_ip" {
  description = "Public IP of the App Server EC2 instance."
  value       = aws_instance.app_server.public_ip
}
