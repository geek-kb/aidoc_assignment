variable "parameters" {
  description = "A map of parameters to create in SSM Parameter Store."
  type = map(object({
    name        = string
    type        = string  # Valid values: "String", "StringList", "SecureString"
    value       = string
    description = optional(string, "")
    key_id      = optional(string, null) # Required for SecureString
    overwrite   = optional(bool, false)
    tags        = optional(map(string), {})
  }))
}

variable "tags" {
  description = "A map of tags to apply to all parameters."
  type        = map(string)
  default     = {}
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
  default = ""
}
