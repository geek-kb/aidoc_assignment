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

dependency "s3_state" {
  config_path = "../../../_bootstrap/s3/terraform-state"

  mock_outputs = {
    s3_bucket_arn = "arn:aws:s3:::${local.assignment_prefix}-terraform-state"
  }
}

dependency "dynamodb_state_locks" {
  config_path = "../../../_bootstrap/dynamodb/terraform-state-locks"

  mock_outputs = {
    table_arn = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/mock-table-id"
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
          "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-terraform"
        ]
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-github-actions-workflows"
        ]
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:geek-kb/aidoc_assignment:*"
          ]
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

  inline_policies_to_attach = {
    DynamoDB-Locks = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:PutItem",
            "dynamodb:GetItem",
            "dynamodb:DescribeTable",
            "dynamodb:DeleteItem",
            "dynamodb:CreateTable"
          ],
          "Resource" : "${dependency.dynamodb_state_locks.outputs.table_arn}"
        }
      ]
    },
    S3-State = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:ListBucket",
            "s3:GetBucketVersioning",
            "s3:GetObject",
            "s3:GetBucketAcl",
            "s3:GetBucketLogging",
            "s3:CreateBucket",
            "s3:PutObject",
            "s3:PutBucketPublicAccessBlock",
            "s3:PutBucketTagging",
            "s3:PutBucketPolicy",
            "s3:PutBucketVersioning",
            "s3:PutEncryptionConfiguration",
            "s3:PutBucketAcl",
            "s3:PutBucketLogging",
            "s3:ListBucket",
            "s3:GetBucketVersioning",
            "s3:GetObject"
          ],
          "Resource" : "arn:aws:s3:::terraform-state-l9bsjdh"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:GetObject",
            "s3:PutObject",
            "s3:GetObjectAcl"
          ],
          "Resource" : "arn:aws:s3:::terraform-state-l9bsjdh/*"
        }
      ]
    }
  }

  tags = {
    Environment = "${local.environment_name}"
    Project     = "ordering-system"
  }
}
