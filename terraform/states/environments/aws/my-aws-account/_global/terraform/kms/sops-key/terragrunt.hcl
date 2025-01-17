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
  source = "${get_repo_root()}/terraform/modules/kms"
}

inputs = {
#  create_kms_key = true
  kms_key_description = "KMS Key for SOPS Encryption"
  kms_key_alias       = "sops-key"
  kms_admins          = ["arn:aws:iam::${local.account_id}:role/AdminRole"]
  sops_roles          = ["arn:aws:iam::${local.account_id}:role/sops-role"]

  tags = {
    Environment = "bootstrap"
    Project     = "ordering-system"
  }
}

