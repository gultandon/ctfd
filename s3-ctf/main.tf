resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

resource "aws_s3_bucket" "website" {
  bucket        = "ctf-web-${random_pet.suffix.id}"
  force_destroy = true

  tags = merge(local.common_tags, { Name = "ctf-web-${random_pet.suffix.id}" })
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document { suffix = "index.html" }
  error_document { key    = "index.html" }
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket     = aws_s3_bucket.website.id
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource  = "${aws_s3_bucket.website.arn}/*"
      },
      {
        Sid       = "PublicListBucket"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:ListBucket", "s3:ListBucketVersions"]
        Resource  = aws_s3_bucket.website.arn
      }
    ]
  })
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/files/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/files/index.html")

  tags = local.common_tags
}

resource "aws_s3_object" "hint_txt" {
  bucket       = aws_s3_bucket.website.id
  key          = "hint.txt"
  source       = "${path.module}/files/hint.txt"
  content_type = "text/plain"
  etag         = filemd5("${path.module}/files/hint.txt")

  tags = local.common_tags
}

# Uploads flag.txt to create version V1, then immediately deletes it to create
# a delete marker — leaving V1 recoverable only via ?versionId=<id>.
resource "null_resource" "flag_version_trick" {
  triggers = {
    bucket_name  = aws_s3_bucket.website.id
    flag_content = var.flag_content
    region       = var.aws_region
  }

  depends_on = [
    aws_s3_bucket_versioning.website,
    aws_s3_bucket_policy.website,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      TMPFILE=$(mktemp /tmp/flag_XXXXXX.txt)
      printf '%s\n' '${var.flag_content}' > "$TMPFILE"

      aws s3api put-object \
        --bucket "${aws_s3_bucket.website.id}" \
        --key flag.txt \
        --body "$TMPFILE" \
        --region "${var.aws_region}"

      aws s3api delete-object \
        --bucket "${aws_s3_bucket.website.id}" \
        --key flag.txt \
        --region "${var.aws_region}"

      rm -f "$TMPFILE"
    EOT
  }
}
