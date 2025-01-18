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

  function_name                      = "order-retrieval"
  bucket_name                        = "ordering-system"
  bucket_directory_and_db_table_name = "orders"
  sqs_queue_name                     = "order-processor"

  assignment_prefix = "aidoc-devops2-ex"
}

terraform {
  source = "${get_repo_root()}/terraform/modules/iam-role"
}

dependency "ecr_order_retrieval" {
  config_path = "../../ecr/${local.function_name}"

  mock_outputs = {
    repository_arn = "arn:aws:ecr:${local.region}:${local.account_id}:repository/${local.function_name}"
  }
}

dependency "s3_ordering_system" {
  config_path = "../../s3/${local.bucket_name}"

  mock_outputs = {
    s3_bucket_arn = "arn:aws:s3:::${local.assignment_prefix}-${local.bucket_name}"
  }
}

dependency "dynamodb_orders" {
  config_path = "../../dynamodb/${local.bucket_directory_and_db_table_name}"

  mock_outputs = {
    table_arn = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${local.bucket_directory_and_db_table_name}"
  }
}

dependency "sqs_order_processor" {
  config_path = "../../sqs/${local.sqs_queue_name}"

  mock_outputs = {
    queue_arn = "arn:aws:sqs:${local.region}:${local.account_id}:${local.sqs_queue_name}"
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
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policies_to_attach = {
    # ECR Access: Restrict access to the order-retrieval repository only
    ECRAccess = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "ecr:BatchGetImage",
            "ecr:GetDownloadUrlForLayer"
          ],
          "Resource" : dependency.ecr_order_retrieval.outputs.repository_arn
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ecr:GetAuthorizationToken"
          ],
          "Resource" : "*"
        }
      ]
    },

    # Lambda Execution: Allows logging and necessary permissions for execution
    LambdaExecution = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.assignment_prefix}-${local.parent_folder_name}:*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords"
          ],
          "Resource" : "*"
        }
      ]
    },

    # S3 Access: (Assumed based on Lambda needing access to an S3 bucket)
    S3ReadAccess = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:GetObject",
            "s3:ListBucket"
          ],
          "Resource" : [
            "${dependency.s3_ordering_system.outputs.s3_bucket_arn}",
            "${dependency.s3_ordering_system.outputs.s3_bucket_arn}/*"
          ]
        }
      ]
    },

    # DynamoDB Access: (If Lambda needs to read from a DynamoDB table)
    DynamoDBReadAccess = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ],
          "Resource" : dependency.dynamodb_orders.outputs.table_arn
        }
      ]
    },

    # SQS Access: (If Lambda needs to send messages to an SQS queue)
    SQSSendMessage = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sqs:SendMessage"
          ],
          "Resource" : dependency.sqs_order_processor.outputs.queue_arn
        }
      ]
    }
  }

  tags = {
    Environment = local.environment
    Project     = "ordering-system"
  }
}
