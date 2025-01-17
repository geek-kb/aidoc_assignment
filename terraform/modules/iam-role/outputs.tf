output "arn" {
  value = one(aws_iam_role.this[*].arn)
}

output "id" {
  value = one(aws_iam_role.this[*].id)
}
