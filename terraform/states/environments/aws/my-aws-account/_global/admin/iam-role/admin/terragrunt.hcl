include {
  path = find_in_parent_folders()
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.account_id
}

terraform {
  source = "${get_repo_root()}/terraform/modules/iam-role"
}

inputs = {
  role_name = "AdminRole"

  max_session_duration = 14400

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${local.account_id}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
EOF

  managed_iam_policies_to_attach = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]

  tags = {
    Environment = "bootstrap"
    Project     = "ordering-system"
  }
}
