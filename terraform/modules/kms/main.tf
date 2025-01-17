# KMS Key (if enabled)
resource "aws_kms_key" "this" {  
  description             = "KMS key for secure encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = var.enable_key_rotation
#  is_enabled              = true
  key_usage               = var.key_usage
  customer_master_key_spec = var.key_spec
  multi_region            = var.enable_multi_region

  policy = var.kms_policy != "" ? var.kms_policy : jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/itaig" },
        Action    = "kms:*",
        Resource  = "*"
      }
    ]
  })

  tags = var.tags
}

# KMS Key Alias (if provided)
resource "aws_kms_alias" "this" {
  name          = "alias/${var.kms_key_alias}"
  target_key_id = aws_kms_key.this.id
}

# Get the current AWS account ID
data "aws_caller_identity" "current" {}
