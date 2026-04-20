# Lab Overview

Follow the core concept in Terraform: up and running writing IaS.

This lab finished the chapter 2, 3, and 4, and also implement some of the elegant practice from chapter 7, and 10 in advance.

> [!WARNING]
>
> I start using Terragrunt in the middle of this lab, since the book mentioned this tool. It turns out it is a pretty bad decision, since I now have to migrate the example in the book to the pattern that terragrunt is using. Although this is a good learning experience, but it also distract me from the core terraform concept.
> I believe that having a better foundation on how terraform works and what are the popular patterns, can provide me more value from terragrunt, since I can finally understand what problems it is trying to solve.
> Therefore, I recommend everyone who want to follow this lab stick to the content of this book first, and move on to the terragrunt in the next lab, in which we will migrate a static website practice written in terraform to terragrunt.

## Ch 2: Basic Flow

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

## Ch 3: State

Terraform is declarative expression for the state of an infrastructure. The modification me made to terraform codebase represents the desired state of the infrastructure, and there will be a shared, single source of truth of the current state of infrastructure.

- It naturally having a reconciliation process to compare between desired state and the current state.
- It needs an additional locking system to prevent changes being made the current state from multiple parties at the same time.
- It needs an additional secret management system to hide the sensitive data in infrastructure.

> The book setup a dedicated S3 bucket to host the shared remote state, and a dynamodb for locking system. These services should be setup individually.

### Blast Radius: state separation

When running `terraform` commands under a directory, the services defined in the dir will be managed with the same `.tfstate` file. To separate the individual service out, we normally isolate the different services under different file structures. How to separate terraform module depends on your needs. For example, we can separate modules base on the environment (stage, prod), services (FE, BE, DB), and AWS resources (VPC, lambda).

Here is the recommended separation from the book:

- environment:
  - stage: pre-production (testing)
  - prod: production
  - mgmt: DevOps tooling (bostion host, CI server)
  - global: resources used across all environments (S3, IAM)
- components: (under each environment)
  - vpc: network topology for this environment
  - services:  apps/microservices (FE, BE)
  - data-storage: data stores to run in this environment
- terraform config: (under each components)
  - `versions.tf`: terraform version, and provider versions
  - `providers.tf`: provider configurations
  - `backend.tf`: setup remote backend state
  - `variables.tf`: input parameters
    - `vars-optional.tf`
    - `vars-required.tf`
    - `vars-local.tf`
  - `outputs.tf`: exported values
  - `main.tf`: resources configuration
  - `dependencies.tf`: data sources

> [!NOTE]
> The remote state can be further used as a data source, and we can fetch output values from remote terraform state with `data.terraform_remote_state.<NAME>.outputs.<ATTRIBUTE>`. Note that the we have to setup the terraform data source in `dependencies.tf` first.

---

## Refinement Plan

- tighten the network model
  - move ASG instances into private subnets
  - stop using default VPC and default subnets for this lab
- define a dedicated VPC layout so the network intent is explicit in terraform
  - two public subnets for ALB across different AZs
  - two private subnets for ASG across different AZs
  - add internet gateway for public ingress to the ALB
  - add route tables for public subnet and private subnet
  - add NAT for outbound internet access if need to
- restrict ingress to the instances
  - replace instance SG ingress with ALB security group

## Reference

- [Terragrunt Crash Course @Java Home Cloud](https://www.youtube.com/watch?v=chMAwiNaAak&t=3s)
