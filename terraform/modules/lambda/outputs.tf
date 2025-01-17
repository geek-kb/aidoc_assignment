output "lambda_arn" {
  value = aws_lambda_function.this.arn
}

output "lambda_invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}

output "lambda_function_url" {
  value = aws_lambda_function_url.this[*].function_url
}
