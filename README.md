# 🚩 CTF Infrastructure

> Terraform-powered Capture The Flag platform and challenge deployments on AWS.

[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-cloud-orange.svg)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

This repository contains the infrastructure-as-code for running CTF (Capture The Flag) events on AWS. It includes two related projects:

| Project | Description |
|---|---|
| [`ctfd-platform/`](ctfd-platform/) | Deploy a full CTFd instance on EC2 behind CloudFront |
| [`s3-ctf/`](s3-ctf/) | An S3 misconfiguration challenge teaching bucket enumeration and version history |

---

## 🗂️ Repository Structure

```
ctfd/
├── ctfd-platform/          # CTFd application deployment
│   ├── main.tf             # EC2, security group, EIP, CloudFront
│   ├── providers.tf        # AWS, TLS, random, local providers
│   ├── variables.tf        # Instance type, region, SSH CIDR
│   ├── outputs.tf          # CloudFront URL, SSH command
│   ├── locals.tf           # Naming prefix and common tags
│   ├── user_data.sh        # Bootstrap: Docker, CTFd, Compose
│   └── .terraform.lock.hcl # Provider lock file
├── s3-ctf/                 # S3 versioning CTF challenge
│   ├── main.tf             # Bucket, versioning, policy, flag trick
│   ├── providers.tf        # AWS, random, null providers
│   ├── variables.tf        # Region, flag content, environment
│   ├── outputs.tf          # Website URL for players
│   ├── locals.tf           # Common tags
│   ├── files/
│   │   ├── index.html      # Challenge landing page
│   │   └── hint.txt        # In-world hint document
│   ├── spec.txt            # Challenge specification
│   ├── writeup.md          # Step-by-step solution walkthrough
│   └── interview-prep.md   # Project critique and Q&A
├── LICENSE
└── README.md               # ← you are here
```

---

## 🚀 Quick Start

### Prerequisites

- **Terraform ≥ 1.5**
- **AWS credentials** configured (via environment variables, `~/.aws/credentials`, or IAM role)
- **AWS CLI** (required for the S3 CTF flag trick)

### Deploy the CTFd Platform

```bash
cd ctfd-platform
terraform init
terraform plan
terraform apply
```

After apply, share the CloudFront URL with participants:

```bash
terraform output cloudfront_url
```

### Deploy the S3 Challenge

```bash
cd s3-ctf
terraform init
terraform plan -var 'flag_content=CTF{your_custom_flag}'
terraform apply -var 'flag_content=CTF{your_custom_flag}'
```

Give players the website URL:

```bash
terraform output website_url
```

---

## 🧩 How the Challenges Work

### CTFd Platform

Deploys a fully-functional CTFd instance on EC2:

- **Amazon Linux 2023** AMI with Docker and Docker Compose
- Clones the official [CTFd/CTFd](https://github.com/CTFd/CTFd) repository
- Generates a random `SECRET_KEY` at boot
- Fronted by **CloudFront** for HTTPS and edge caching
- Security group locked to **CloudFront origin-facing IPs** only (port 8000)
- SSH access via auto-generated RSA key pair

### S3 Challenge ("Glistening Oasis")

A beginner-friendly cloud security challenge teaching:

1. **S3 static website URL format** — reveals bucket name and region
2. **S3 REST API enumeration** (`?list-type=2`) — discovers hidden files
3. **S3 versioning** (`?versions`) — reveals deleted objects
4. **Version ID retrieval** (`?versionId=`) — fetches the flag

The flag is uploaded to the bucket and immediately deleted, leaving a delete marker. Versioning is enabled and the bucket policy grants public `s3:ListBucketVersions`, allowing players to discover and recover the deleted flag.

---

## 🧹 Cleanup

```bash
# Destroy S3 challenge
cd s3-ctf && terraform destroy

# Destroy CTFd platform
cd ctfd-platform && terraform destroy
```

Both projects use `force_destroy = true` on S3 buckets and no `deletion_protection` for easy teardown in development environments.

---

## 🔐 Security Notes

- CTFd platform: The SSH private key is written locally as `ctfd-key.pem` with `0400` permissions. Rotate or delete it after the event.
- S3 challenge: The flag variable is marked `sensitive = true` in Terraform but has a default value. For actual events, pass the flag at apply time: `-var 'flag_content=CTF{...}'`.
- The S3 bucket is intentionally public with versioning enabled — this is the challenge mechanic. Tear it down after the event.

---

## 📚 Further Reading

- [`ctfd-platform/`](ctfd-platform/) — CTFd deployment details
- [`s3-ctf/`](s3-ctf/) — Challenge details, writeup, and interview prep

---

## 📄 License

MIT © Gul Tandon
