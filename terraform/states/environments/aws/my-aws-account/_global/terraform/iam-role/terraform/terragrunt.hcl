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

dependency "iam_role_github_actions_workflows" {
  config_path = "../../../github-actions-workflows/iam-role/github-actions-workflows"

  mock_outputs = {
    arn = "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-github-actions-workflows"
  }
}

dependency "iam_role_sops" {
  config_path = "../sops-role"

  mock_outputs = {
    arn = "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-sops-role"
  }
}

dependency "s3_state" {
  config_path = "../../../_bootstrap/s3/terraform-state"

  mock_outputs = {
    s3_bucket_arn = "arn:aws:s3:::${local.assignment_prefix}-terraform-state",
  }
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
          "${dependency.iam_role_github_actions_workflows.outputs.arn}",
          "${dependency.iam_role_sops.outputs.arn}"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  inline_policies_to_attach = {
    S3-Terraform-State = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject",
            "s3:GetBucketVersioning",
            "s3:PutBucketVersioning",
            "s3:DeleteObject"
          ],
          "Resource" : [
            "${dependency.s3_state.outputs.s3_bucket_arn}",
            "${dependency.s3_state.outputs.s3_bucket_arn}/*"
          ]
        }
      ]
    },
    DynamoDB-Terraform-Locks = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:PutItem",
            "dynamodb:GetItem",
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable"
          ],
          "Resource" : "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${local.assignment_prefix}-terraform-state-locks"
        }
      ]
    },
    Lambda-Deployment = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "lambda:CreateFunction",
            "lambda:UpdateFunctionConfiguration",
            "lambda:UpdateFunctionCode",
            "lambda:ListFunctions",
            "lambda:GetFunction",
            "lambda:DeleteFunction"
          ],
          "Resource" : "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.assignment_prefix}-*"
        }
      ]
    },
    KMS-Access = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ],
          "Resource" : "*"
        }
      ]
    },
    IAM-AssumeRole = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Resource" : [
            "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-state-manager"
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
