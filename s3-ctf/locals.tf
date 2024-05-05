locals {
  common_tags = {
    Project     = "s3-ctf"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
