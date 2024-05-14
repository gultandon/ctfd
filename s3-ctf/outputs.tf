output "website_url" {
  description = "S3 static website URL — share this with players as the starting point"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}
