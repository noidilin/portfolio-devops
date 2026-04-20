output "alb_dns_name" {
  description = "The domain name of the load balancer."
  value       = module.webserver_cluster.alb_dns_name
}

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = module.webserver_cluster.asg_name
}
