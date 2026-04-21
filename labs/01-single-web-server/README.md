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

## Ch 4: Avoid duplication with Terraform modules

We implement a better separation of concern with dedicated directory for each environments/components, which results in lots of duplicated configuration files. Terraform has a solution for us to share the reusable configuration across the separated directories, called module.

> Any set of Terraform configuration files in a folder is a module.

### Variables

- input parameters: `vars-required.tf`
- exported values: `outputs.tf`

We needs to pass in variables to child/reusable modules to create different variation for our needs. For example, stage and production environment might need to pass in different parameters to setup resources.

I use `.auto.tfvars` to handle required variables in previous chapter, but variables in `.auto.tfvars` only passed in as variables of root module, and they won't be passed to child module automatically. Similarly, the exported values from child modules also won't get exported automatically in the root module.

Therefore, we need to wire up the input parameters with:

- `vars-required.tf`: setup required variables in root module
- `.auto.tfvars`: actual values to pass in
- `main.tf`: configure `module` to pass root module variables into child module

In addition, wire up the exported values with:

- `outputs.tf`: we can reference module outputs with `module.<MODULE_NAME>.<OUTPUT_NAME>`

### Inline Blocks and the `import` fix

When extracting the inline rules block of security group to a standalone SG rule resources, terraform start treating those rules as different state objects. The AWS rules already existed, but terraform no longer had matching standalone rule entries in state. So on apply, it tried to create them again and AWS rejected that with `InvalidPermission.Duplicate`

The root cause of this mismatch is that inline rules are not first-class terraform resources with their own addresses in state. They are attributes nested under the security group resources. Therefore, terraform cannot automatically infer the 'old inline rule' is the same thing as the 'new standalone SG rule resource'.

The solution is to attach the existing remote rules to the newly created SG rule with real AWS rule IDs using `import` block. The `import` block tells terraform that this resource address in configuration corresponds to this already-existing remote object. The `import` allows terraform to understand this new terraform resource is already backed by AWS rule, so terraform stops trying to create a duplicate.

I use the AWS MCP tool to locate the corresponding SG rule's ID, and the MCP tool is using these `aws` command to investigate:

- `aws ec2 describe-security-group-rules`

#### What about `moved`

I tried to use `moved` to remapped the previous implementation to the standalone resources, but can't manage to fix the issue. It seems like `moved` only remaps 'state addresses', not remote objects.

The use case is more like these scenario:

- resource renamed
- resource moved into a module (refactor)

Terraform can move state from old address to new address because both sides are terraform resource 'addresses', while in our case, the old SG rules are merely inline nested block inside `aws_security_group`. There is no state address from the old implementation for terraform to move from.

#### The bottom line

To sum up, the real issue occurred because the migration changed Terraform state shape without changing the AWS objects, so Terraform needed help to re-link the new resource addresses to the already-existing rules.

Use `import` when:

- remote object already exists, but state doesn't track it with resources address
  - manually created, created by older config
- terraform config now declares a resource for it
  - adopting existing infrastructure into terraform

Use `moved` when:

- remote object is already manged by Terraform
- changes are made to resource address
  - renaming resource
  - moving resource into module
  - refactoring module structure

### Directory convention `live` + `modules`

We separate the root module used directly for infrastructure under `live` dir, and keep all the reusable child modules under `modules` to make the boundary more clear, and also use a different version control repository to manage each modules.

I didn't host the module on a dedicated repo due to my current repo's structure, and since my implementation has some latest practice advocated by terraform, such as `aws_vpc_security_group_egress_rule` instead of `aws_security_group_rule`, this lab cannot use the provided repo from the book either. Hence, I will keep using the local modules.

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
