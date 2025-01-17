variable "function_name" {
  type        = string
  description = "Lambda function name"
}

variable "iam_lambda_role_arn" {
  type        = string
  description = "IAM Role ARN for Lambda"
}

variable "handler" {
  type        = string
  default     = "lambda_function.lambda_handler"
  description = "Handler function for Lambda (ignored if containerized)"
}

variable "runtime" {
  type        = string
  default     = "python3.9"
  description = "Lambda runtime (ignored if containerized)"
}

variable "timeout" {
  type    = number
  default = 60
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "containerization" {
  type    = bool
  default = false
}

variable "image_uri" {
  type    = string
  default = null
}

variable "enable_function_url" {
  type    = bool
  default = false
}

variable "function_url_cors" {
  type = object({
    allow_origins  = list(string)
    allow_methods  = list(string)
    allow_headers  = list(string)
    expose_headers = list(string)
    max_age        = number
  })
  default = null
}

variable "log_retention" {
  type    = number
  default = 7
}

variable "lambda_environment" {
  type    = map(string)
  default = {}
}

variable "enable_s3_trigger" {
  type    = bool
  default = false
}

variable "s3_bucket_name" {
  type    = string
  default = ""
}

variable "s3_trigger_directory" {
  type    = string
  default = ""
}

variable "function_directory" {
  type    = string
  default = ""
}

variable "function_zip_filename" {
  type    = string
  default = "lambda.zip"
}

variable "function_source_zip_path" {
  type    = string
  default = ""
}

variable "function_source_code_path" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}