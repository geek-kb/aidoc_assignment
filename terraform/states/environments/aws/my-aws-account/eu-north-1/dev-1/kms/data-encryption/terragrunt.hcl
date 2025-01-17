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
}

terraform {
  source = "${get_repo_root()}/terraform/modules/kms"
}

inputs = {
  kms_key_alias = "${local.parent_folder_name}-key"
  description   = "KMS Key for encrypting application data"
  key_usage     = "ENCRYPT_DECRYPT"
  key_rotation  = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${get_aws_account_id()}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Purpose     = "Data Encryption"
  }
}

