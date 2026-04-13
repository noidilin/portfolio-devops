
> Internet-> ALB SG: `80` -> ALB listener -> target group: `8080` -> ASG instances

1. Request: user request comes in
2. ALB: default VPC and subnets
   1. listeners:
      - accept HTTP on port `80`
   2. listener rules:
      - matches `*` and forwards to target group
3. ALB target group: bridge ASG and ALB within default VPC/subnets
   - expects traffic on port `8080`
   - health check hits on the instance traffic port and require HTTP `200`
4. ASG: default VPC and subnets
   - instances launched by ASG is automatically registered/deregistered with ALB target group
5. launch template
   - attach dedicated security group to the instance launched by ASG

> [!WARNING]
> With the current setup, traffic can potentially bypass the ALB and hit instances directly.
