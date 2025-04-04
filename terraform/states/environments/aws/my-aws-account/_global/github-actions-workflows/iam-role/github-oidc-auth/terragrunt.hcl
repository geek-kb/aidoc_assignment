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
  repos_list = [
    "geek-kb/aidoc_assignment"
  ]
}

terraform {
  source = "${get_repo_root()}/terraform/modules/iam-role"
}

dependency "github_oidc" {
  config_path = "../../../_bootstrap/github-oidc/github-oidc-provider"

  mock_outputs = {
    arn = "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
  }
}

inputs = {
  role_name = "${local.assignment_prefix}-${local.parent_folder_name}"

  max_session_duration = 14400

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "${dependency.github_oidc.outputs.arn}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          "StringLike" = {
            "token.actions.githubusercontent.com:sub" : [
              for repo in "${local.repos_list}" : "repo:${repo}:*"
            ]
          },
          "StringEquals" = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  policy = {
    assume_roles = {
      actions = ["sts:AssumeRole"]
      resources = [
        "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-github-actions-workflows",
        "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-terraform",
        "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-state-manager"
      ]
    }
  }

  tags = {
    Environment = local.environment_name
    Project     = "ordering-system"
  }
}
