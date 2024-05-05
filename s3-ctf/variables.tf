variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "flag_content" {
  description = "The flag string written into flag.txt"
  type        = string
  sensitive   = true
  default     = "CTF{s3_v3rs10n_h1st0ry_n3v3r_l13s}"
}

variable "environment" {
  description = "Environment name used in resource tags"
  type        = string
  default     = "ctf"
}
