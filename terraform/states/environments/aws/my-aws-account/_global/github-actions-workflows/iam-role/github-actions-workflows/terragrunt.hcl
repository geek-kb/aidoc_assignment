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

  assignment_prefix    = "aidoc-devops2-ex"
  lambda_function_name = "order_retrieval"
}

terraform {
  source = "${get_repo_root()}/terraform/modules/iam-role"
}

dependency "kms_terraform_state" {
  config_path = "../../../_bootstrap/kms/terraform-state-key"

  mock_outputs = {
    key_arn = "arn:aws:kms:${local.region}:${local.account_id}:key/mock-key-id"
  }
}

dependency "kms_sops" {
  config_path = "../../../_bootstrap/kms/sops-key"

  mock_outputs = {
    key_arn = "arn:aws:kms:${local.region}:${local.account_id}:key/mock-key-id"
  }
}

dependency "github_oidc_provider" {
  config_path = "../../../_bootstrap/github-oidc/github-oidc-provider"

  skip_outputs = true # No outputs needed

  mock_outputs = {
    arn = "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
  }
}

dependency "iam_role_github_oidc_auth" {
  config_path = "../../../github-actions-workflows/iam-role/github-oidc-auth"

  mock_outputs = {
    arn = "arn:aws:iam::${local.account_id}:role/${local.assignment_prefix}-github-oidc-auth"
  }
}

dependency "ecr_order_retrieval" {
  config_path = "../../../../${local.region}/dev-ireland-1/ecr/order-retrieval"

  mock_outputs = {
    repository_arn = "arn:aws:ecr:${local.region}:${local.account_id}:repository/order-retrieval"
  }
}

dependency "lambda_order_retrieval" {
  config_path = "../../../../${local.region}/dev-ireland-1/lambda/order-retrieval"

  mock_outputs = {
    function_arn = "arn:aws:lambda:${local.region}:${local.account_id}:function/${local.lambda_function_name}"
  }
}

dependency "lambda_order_verification" {
  config_path = "../../../../${local.region}/dev-ireland-1/lambda/order-verification"

  mock_outputs = {
    function_arn = "arn:aws:lambda:${local.region}:${local.account_id}:function/${local.lambda_function_name}"
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
        "AWS": "${dependency.iam_role_github_oidc_auth.outputs.arn}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  inline_policies_to_attach = {
    TerraformResourceAccess = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:GenerateDataKey",
            "kms:DescribeKey",
            "kms:ListKeys"
          ],
          Resource = [
            dependency.kms_terraform_state.outputs.key_arn,
            dependency.kms_sops.outputs.key_arn
          ]
        }
      ]
    },
    ECRAccess = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecr:GetAuthorizationToken"
          ],
          Resource = "*"
        },
        {
          Effect = "Allow",
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:DescribeImages",
            "ecr:BatchGetImage" # New: Needed to retrieve image metadata
          ],
          Resource = dependency.ecr_order_retrieval.outputs.repository_arn
        }
      ]
    },
    LambdaDeploy = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "lambda:GetFunction",
            "lambda:GetFunctionConfiguration", # New: Needed for checking function config
            "lambda:UpdateFunctionCode"
          ],
          Resource = dependency.lambda_order_retrieval.outputs.lambda_arn
        }
      ]
    },
    S3Access = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:ListBucket"
          ],
          Resource = [
            "arn:aws:s3:::your-s3-bucket",
            "arn:aws:s3:::your-s3-bucket/*"
          ]
        }
      ]
    },
    TerraformStateAccess = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ],
          Resource = "arn:aws:s3:::your-terraform-state-bucket/*"
        },
        {
          Effect = "Allow",
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem"
          ],
          Resource = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/your-terraform-lock-table"
        }
      ]
    },
    IAMPassRole = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect   = "Allow",
          Action   = "iam:PassRole",
          Resource = "arn:aws:iam::${local.account_id}:role/lambda-execution-role"
        }
      ]
    }
  }

  tags = {
    Environment = local.environment_name
    Project     = "ordering-system"
  }
}
