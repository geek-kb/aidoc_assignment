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
        "AWS": [
          "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-admin",
          "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-github-actions-workflows",
          "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-sops-role"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  inline_policies_to_attach = {
    S3-Terraform-State = {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject",
            "s3:GetBucketVersioning",
            "s3:PutBucketVersioning",
            "s3:DeleteObject"
          ],
          "Resource": [
            "arn:aws:s3:::${local.assignment_prefix}-terraform-state",
            "arn:aws:s3:::${local.assignment_prefix}-terraform-state/*"
          ]
        }
      ]
    },
    DynamoDB-Terraform-Locks = {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "dynamodb:PutItem",
            "dynamodb:GetItem",
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable"
          ],
          "Resource": "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${local.assignment_prefix}-terraform-state-locks"
        }
      ]
    },
    Lambda-Deployment = {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "lambda:CreateFunction",
            "lambda:UpdateFunctionConfiguration",
            "lambda:UpdateFunctionCode",
            "lambda:ListFunctions",
            "lambda:GetFunction",
            "lambda:DeleteFunction"
          ],
          "Resource": "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.assignment_prefix}-*"
        }
      ]
    },
    IAM-AssumeRole = {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "sts:AssumeRole",
          "Resource": [
            "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-state-manager",
            "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-terraform"
          ]
        }
      ]
    }
  }

  tags = {
    Environment = local.environment_name
    Project     = "ordering-system"
  }
}
