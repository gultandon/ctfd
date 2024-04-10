resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

# ── SSH Key Pair ──────────────────────────────────────────────────────────────

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ctfd" {
  key_name   = local.name_prefix
  public_key = tls_private_key.ec2_key.public_key_openssh

  tags = local.common_tags
}

# Written to the module directory so the operator can SSH in.
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ec2_key.private_key_pem
  filename        = "${path.module}/ctfd-key.pem"
  file_permission = "0400"
}

# ── Networking ────────────────────────────────────────────────────────────────

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# CloudFront origin-facing IPs — used to lock down the EC2 security group so
# only CloudFront edge nodes can reach port 8000.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "ctfd" {
  name        = local.name_prefix
  description = "CTFd - HTTP from CloudFront origin IPs, SSH from allowed CIDR"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from CloudFront"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = local.name_prefix })
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "ctfd" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ctfd.key_name
  vpc_security_group_ids      = [aws_security_group.ctfd.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true

    tags = merge(local.common_tags, { Name = "${local.name_prefix}-root" })
  }

  user_data = file("${path.module}/user_data.sh")

  tags = merge(local.common_tags, { Name = local.name_prefix })
}

resource "aws_eip" "ctfd" {
  domain = "vpc"

  depends_on = [data.aws_vpc.default]

  tags = merge(local.common_tags, { Name = local.name_prefix })
}

resource "aws_eip_association" "ctfd" {
  instance_id   = aws_instance.ctfd.id
  allocation_id = aws_eip.ctfd.id
}

# ── CloudFront Distribution ───────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "ctfd" {
  enabled     = true
  comment     = "CTFd - ${random_pet.suffix.id}"
  price_class = "PriceClass_All"

  origin {
    domain_name = aws_instance.ctfd.public_dns
    origin_id   = "ctfd-ec2"

    custom_origin_config {
      http_port              = 8000
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "ctfd-ec2"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # CachingDisabled — CTFd is fully dynamic
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AllViewer — forward all headers/cookies/QS; Host: <cloudfront-domain> reaches
    # the origin so CTFd generates correct absolute URLs
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags
}
