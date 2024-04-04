variable "aws_region" {
  description = "AWS region to deploy EC2 into"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type for CTFd"
  type        = string
  default     = "t3.medium"
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "environment" {
  description = "Environment name used in resource tags"
  type        = string
  default     = "ctf"
}
