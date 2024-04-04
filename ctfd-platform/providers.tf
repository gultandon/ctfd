terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  backend "s3" {
      bucket         = "my-terraform-state-bucket-gul1234"
      key            = "ctfd/terraform.tfstate"
      region         = "ap-south-1"
      use_lockfile   = true
      encrypt        = true
    }
}

provider "aws" {
  region = var.aws_region
}
