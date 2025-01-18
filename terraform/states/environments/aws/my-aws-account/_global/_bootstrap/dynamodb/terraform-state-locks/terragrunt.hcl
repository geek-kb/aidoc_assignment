include {
  path = find_in_parent_folders()
}

locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_name     = local.account_vars.locals.account_name
  account_id       = local.account_vars.locals.account_id
  region           = local.region_vars.locals.region
  environment      = local.environment_vars.locals.environment
  environment_name = local.environment_vars.locals.environment_name

  parent_folder_path  = split("/", path_relative_to_include())
  parent_folder_index = length(local.parent_folder_path) - 1
  parent_folder_name  = element(local.parent_folder_path, local.parent_folder_index)

  assignment_prefix = "aidoc-devops2-ex"
}

terraform {
  source = "${get_repo_root()}/terraform/modules/dynamodb"
}

inputs = {
  table_name   = "${local.environment_name}-${local.parent_folder_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  environment  = local.environment

  attributes = [
    {
      name = "LockID"
      type = "S"
    }
  ]

  tags = {
    Environment_Name = local.environment_name
    Project          = "ordering-system"
  }
}
