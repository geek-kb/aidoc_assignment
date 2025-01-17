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
  source = "${get_repo_root()}/terraform/modules/iam-role"
}

#dependency "s3" {
#  config_path = "../../../terraform/s3/aidoc-devops2-ex-terraform-state"
#}
#
#dependency "dynamodb" {
#  config_path = "../../../terraform/dynamodb/terraform-state-locks"
#}
#
#dependency "kms_terraform_state" {
#  config_path = "../../../terraform/kms/terraform-state-key"
#}
#
#dependency "kms_sops" {
#  config_path = "../../../terraform/kms/sops-key"
#}

inputs = {
  role_name = "${local.assignment_prefix}-${local.parent_folder_name}"

  max_session_duration = 14400

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

  managed_iam_policies_to_attach = [
    "arn:aws:iam::aws:policy/PowerUserAccess"
  ]

  inline_policies_to_attach = {
    AssumeTerraformRoles = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Resource" : [
            "arn:aws:iam::${local.account_id}:role/TerraformStateManager",
            "arn:aws:iam::${local.account_id}:role/terraform"
          ]
        }
      ]
    }
  }

  tags = {
    Environment = "bootstrap"
    Project     = "ordering-system"
  }
}
