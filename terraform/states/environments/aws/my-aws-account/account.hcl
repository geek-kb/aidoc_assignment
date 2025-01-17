locals {
  account_name      = "my-aws-account"
  account_id        = "912466608750"
  canonical_user_id = "" # Required for cross-account access to buckets and objects using s3
  iam_role_name     = "Terraform"
  iam_role_arn      = "arn:aws:iam::912466608750:role/Terraform"
}
