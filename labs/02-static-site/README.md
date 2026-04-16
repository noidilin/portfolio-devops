## Working with terraform projects

With the naming convention in Terraform projects, the module contract is the following:

- composition in `main.tf`
- inputs in `vars*.tf`
- exported values in `outputs.tf`

A good way to read Terraform projects is to treat it like a call graph.

1. confirm project constraints
   - which cloud is used: `providers.tf`
   - where state lives: `backend.tf` (also how locking works)
   - what Terraform/OpenTofu and provider versions are expected: `versions.tf`
2. start from the root module's entry point
   - how module composite resources: `main.tf`
   - find where root passes variables into a module
3. find where the variables enter the root
   - what must be provided: `vars-required.tf`
   - what has defaults: `vars-optional.tf`
   - what is exposed: `outputs.tf`
4. dive into child module interface
   - see whether the variables are passed deeper
   - repeat this process, until we hit an actual resource

## Step 1

Things different from the official course:

- I am using the S3 bucket I have setup previously to store remote state.
- I am using terraform, since my neovim config is having hard time to pickup the downloaded providers

## Step 2

> [!WARNING]
> move to `module.{module_name}.{previous_resources}`

Although the official documentation move the resources to modules all at once, I recommend to move the resources from `ddb` -> `s3`, -> `iam` -> `lambda` to really understand how to refactor a terraform project.

Here is how I move each resource to its dedicated module:

1. start from `moved.tf` to still utilize the LSP completion feature
2. move `versions.tf` and resource config file
3. add `module` in the `main.tf` so that we can get some feedback from `terraform` plan in the following steps
4. add `vars-required.tf` for the new module, and update `live/main.tf`
5. add `outputs.tf` for the new module to wire up other codes that consuming its exported values.

## Step 3

> [!WARNING]
> move to `module.prod.module.{previous_resources}`

- root module (`live/`): represent deployable stack
- composition module (`best_cat`): wire together reusable modules
- reusable module (`lambda`): manipulate actual resources

All resources  are in the same state file now, so every `apply`, or `destroy` has the potential to modify the multiple envs.

## Step 4
