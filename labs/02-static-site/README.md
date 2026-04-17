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

- introducing `terragrunt.hcl` file into modules allow Terragrunt to recognize the content of this directory as a terragrunt "unit".

I noticed that the `terragrunt run --all plan` introduce a path change for `lambda_zip_file`, and it seems like the terragrunt will flatten the module structure, which make `best_cat` become the Terraform root module inside `.terragrunt-cache`.

Under the old pattern, the zip path was effectively being interpreted from one directory deeper in the module tree, so Terraform recorded `../../dist/best-cat.zip`. With Terragrunt, the same artifact can now be represented one level shorter `../dist/best-cat.zip`.

## Step 6: integrate different unit with dependency

We have separate env in the last step, but inside `prod` and `dev` env we still manage bunch of service in one state file, in other word one terragrunt unit using the `best_cat` composition module. Any `plan` and `apply` for `prod` could touch everything.

> Our goal is moving from "one state file per environment" pattern to "one state file per component, per environment" pattern.

Therefore, we are separating reusable modules to further increase safety regard of blast radius. Since those modules won't have the same state file anymore, we have to use Terragrunt's `dependency` to pull outputs out of state from one unit and pass in inputs to another unit.

In our new pattern, each `live/prod/*` or `live/dev/*` is a Terragrunt unit pointing at its corresponding reusable Terraform module. This is an architectural shift from one composition module (`best_cat`) with one state to multiple Terragrunt units with separate state, joined by dependency.

### Migrating process

Once we setup the `terragrunt.hcl` files in each module, we can start manage them with their own states, but we should build the new state from previous monolithic state from remote state.

- `terragrunt state pull`: pull current state and output to stdout
- `terragrunt state push`: update remote state from a local state file

```sh
# live/prod
terragrunt state pull > /tmp/tofu.tfstate
cd ddb && terragrunt state push /tmp/tofu.tfstate
cd ../iam && terragrunt state push /tmp/tofu.tfstate
cd ../lambda && terragrunt state push /tmp/tofu.tfstate
cd ../s3 && terragrunt state push /tmp/tofu.tfstate
```

These commands create a full copy state records at new backend for each module. The new remote backend state file is determined in `root.hcl` with the `key` field. Note that this step only setup the backend state as a start point, and we are expect to see:

- plenty of destroys (since we modified the module structure)
  - address with `moved.tf`
- plenty of unrelated states from other modules (since we setup remote state with full copy of the previous one)
  - address with `removed.tf`

## Step 7: composite units with Terragrunt Stack

We introduce the reusable units in both `dev` and `prod` env to exchange better separation of concern for each resource, and therefore once again create bunch of duplicated config for those units.

We can simplify those duplicated units:

- ddb
  - `live/dev/ddb/terragrunt.hcl`
  - `live/prod/ddb/terragrunt.hcl`
- s3
  - `live/dev/s3/terragrunt.hcl`
  - `live/prod/s3/terragrunt.hcl`
- iam
  - `live/dev/iam/terragrunt.hcl`
  - `live/prod/iam/terragrunt.hcl`
- lambda
  - `live/dev/lambda/terragrunt.hcl`
  - `live/prod/lambda/terragrunt.hcl`

By introduce a composition terragrunt units:

- `catalog/units/ddb/terragrunt.hcl`
- `catalog/units/s3/terragrunt.hcl`
- `catalog/units/iam/terragrunt.hcl`
- `catalog/units/lambda/terragrunt.hcl`

We parameterize those config in `catalog/units/*`, and use `terragrunt.stack.hcl` in both `dev` and `prod` env to pass in arguments with `values` attribute.

By default, the generated reusable modules will be stored in `.terragrunt-stack` dir. However, this will result in misalignment of the remote backend state for each modules.

To focus on the how stacks work in this step, we adjust this default behavior and assign a dedicated path for each unit in this step by setting `no_dot_terragrunt_stack=true` and `path={module}` for every unit, so that the state for each module located in the same directory.

## Step 8: migrate module's state for terragrunt stack pattern

We have implemented the backbone feature for terragrunt stacks, and also have a clear understand of what problem it solved. Now we can migrate our current remote backend state pattern with the conventional terragrunt stack pattern.

- generated latest state with the current config
- loop through every unit under both env one by one:
  1. dive into old unit dir `live/dev/{unit}`
  2. `terragrunt state pull` its state to `tmp/terraform.tfstate` file
  3. dive into new unit dir `live/dev/.terragrunt-stack/{unit}`
  4. `terragrunt state push` the previous state to new backend directory

Now we have deeply integrated Terragrunt stack in our project.
