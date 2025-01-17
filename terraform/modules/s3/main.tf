resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

# Versioning (if enabled)
resource "aws_s3_bucket_versioning" "this" {
  count = var.enable_versioning ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle Rules (if provided)
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      filter {
        prefix = rule.value.prefix
      }

      dynamic "expiration" {
        for_each = length(rule.value.expiration) > 0 ? [rule.value.expiration] : []
        content {
          days                         = lookup(rule.value.expiration, "days", null)
          expired_object_delete_marker = lookup(rule.value.expiration, "expired_object_delete_marker", null)
        }
      }

      dynamic "transition" {
        for_each = lookup(rule.value, "transition", [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }
}
