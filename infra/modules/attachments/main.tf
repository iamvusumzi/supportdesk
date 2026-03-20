resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "attachments" {
  bucket = "supportdesk-attachments-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "attachments" {
  bucket                  = aws_s3_bucket.attachments.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = ["*"]   # tightened in Phase 4 when we have a real domain
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Lifecycle — delete attachments older than 90 days
resource "aws_s3_bucket_lifecycle_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    id     = "expire-attachments"
    status = "Enabled"

    expiration {
      days = 30
    }

    filter {
      prefix = "attachments/"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}