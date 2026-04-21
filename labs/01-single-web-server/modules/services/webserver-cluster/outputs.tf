output "alb_dns_name" {
  description = "The domain name of the load balancer."
  value       = aws_lb.web_alb.dns_name
}

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web_asg.name
}

output "alb_security_group_id" {
  description = "The ID of the Security Group attached to the load balancer"
  value       = aws_security_group.web_alb_sg.id
}
