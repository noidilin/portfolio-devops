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

## Step 1: setup the project

Things different from the official course:

- I am using the S3 bucket I have setup previously to store remote state.
- I am using terraform, since my neovim config is having hard time to pickup the downloaded providers

## Step 2: add reusable module for resources

> [!WARNING]
> move to `module.{module_name}.{previous_resources}`

Although the official documentation move the resources to modules all at once, I recommend to move the resources from `ddb` -> `s3`, -> `iam` -> `lambda` to really understand how to refactor a terraform project.

Here is how I move each resource to its dedicated module:

1. start from `moved.tf` to still utilize the LSP completion feature
2. move `versions.tf` and resource config file
3. add `module` in the `main.tf` so that we can get some feedback from `terraform` plan in the following steps
4. add `vars-required.tf` for the new module, and update `live/main.tf`
5. add `outputs.tf` for the new module to wire up other codes that consuming its exported values.

## Step 3: add composition module to build new dev env quickly

> [!WARNING]
> move to `module.prod.module.{previous_resources}`

- root module (`live/`): represent deployable stack
- composition module (`best_cat`): wire together reusable modules
- reusable module (`lambda`): manipulate actual resources

All resources  are in the same state file now, so every `apply`, or `destroy` has the potential to modify the multiple envs.

## Step 4: separate out dev and prod module to reduce blast radius

> [!WARNING]
> move to `module.main.module.{previous_resources}`

Breaking our config into `dev` and `prod` root modules can increase the safety for this project with the trade-off that there will be a lots of duplication in both `dev` and `prod` module.

> [!NOTE]
> The previous `.terraform` dir needs to be copied to the new directory for both `dev` and `prod`, so that `terraform init -migrate-state` can migrate to new remote state with the local state stored in the `.terraform` dir.

The content we defined in `removed.tf` didn't actually delete the resource specified by us. Instead, it is more like to 'unmanaged' those resources in this terraform unit. Since we are separating the state (the scope for each terraform command, or the 'blast radius'), we have to un-manage  the resource that are not related to this unit.

- `dev` env: un-manage resources for `prod`
- `prod` env: un-manage resources for `dev`

## Step 5: introduce terragrunt to reduce boilerplate
