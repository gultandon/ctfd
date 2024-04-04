locals {
  name_prefix = "ctfd-${random_pet.suffix.id}"

  common_tags = {
    Project     = "ctfd"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
