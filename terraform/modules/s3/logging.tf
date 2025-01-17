# Logging (if enabled)
resource "aws_s3_bucket_logging" "this" {
  count = var.enable_logging ? 1 : 0

  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_prefix
}