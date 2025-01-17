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
  current_folder      = basename(path_relative_to_include())

  function_name         = "${replace("${local.parent_folder_name}", "-", "_")}"
  function_zip_filename = "${local.function_name}_source_code.zip"
  function_directory = "${get_repo_root()}/terraform/states/environments/aws/${path_relative_to_include()}"
  function_source_code_path = "${local.function_directory}/lambda_source_code"
  function_source_zip_path     = "${local.function_directory}/${local.function_zip_filename}"
}

terraform {
  source = "${get_repo_root()}/terraform/modules/lambda"
}

dependency "iam_role" {
  config_path = "../../iam-role/verification_lambda_execution/terragrunt.hcl"

  mock_outputs = {
    arn = "arn:aws:iam::${local.account_id}:role/verification_lambda_execution"
  }
}

dependency "s3_trigger_bucket" {
  config_path = "../../s3/ordering-system/terragrunt.hcl"

  mock_outputs = {
    bucket_name = "ordering-system"
    bucket_arn = "arn:aws:s3:::ordering-system"
  }
}

dependency "sqs_queue" {
  config_path = "../../sqs/order-processor/terragrunt.hcl"

  mock_outputs = {
    queue_url = "https://sqs.${local.region}.amazonaws.com/${local.account_id}/order-processor"
  }
}

dependency "dynamodb_table" {
  config_path = "../../dynamodb/orders/terragrunt.hcl"

  mock_outputs = {
    table_name = "orders"
  }
}

inputs = {
  function_name   = "${local.function_name}"
  iam_lambda_role_arn = "${dependency.iam_role.outputs.arn}"
  runtime         = "python3.9"
  handler         = "${local.function_name}.lambda_handler"
  memory_size     = 128
  timeout         = 10
  containerization = false

  function_directory = "${local.function_directory}"
  function_zip_filename = "${local.function_zip_filename}"
  function_source_zip_path = "${local.function_source_zip_path}"
  function_source_code_path = "${local.function_source_code_path}"
  function_source_zip_path = "${local.function_source_zip_path}"

  enable_s3_trigger    = true
  s3_bucket_name       = "${dependency.s3_trigger_bucket.outputs.bucket_name}"
  s3_trigger_directory = "orders/"

  enable_function_url = false

  lambda_environment = {
    DYNAMODB_TABLE_NAME = "${dependency.dynamodb_table.outputs.table_name}"
    SQS_QUEUE_URL       = "${dependency.sqs_queue.outputs.queue_url}"
  }
}
