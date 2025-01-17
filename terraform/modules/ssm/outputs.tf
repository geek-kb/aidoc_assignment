output "ssm_parameter_arns" {
  value       = { for k, v in aws_ssm_parameter.this : k => v.arn }
  description = "ARNs of the created SSM parameters."
}

output "ssm_parameter_names" {
  value       = { for k, v in aws_ssm_parameter.this : k => v.name }
  description = "Names of the created SSM parameters."
}

