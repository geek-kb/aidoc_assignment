variable "create_iam_role" {
  type    = bool
  default = true
}

variable "role_name" {
  type    = string
  default = null
}

variable "assume_role_policy" {
  type    = string
  default = null
}

variable "max_session_duration" {
  type    = number
  default = null
}

variable "tags" {
  type = map(string)
}

variable "managed_iam_policies_to_attach" {
  type    = list(any)
  default = []
}

variable "inline_policies_to_attach" {
  type    = any
  default = {}
}

variable "kms_policies_to_attach" {
  description = "Map of KMS policies to attach to the IAM role"
  type        = map(any)
  default     = {}
}

output "iam_role_arn" {
  description = "The ARN of the IAM role"
  value       = aws_iam_role.this[0].arn
}

variable "region" {
  description = "The AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
  default = ""
}
