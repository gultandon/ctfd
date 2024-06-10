# 🖥️ CTFd Platform — AWS Deployment

> One-command Terraform deployment of a production-ready CTFd instance on EC2 behind CloudFront.

[![Terraform](https://img.shields.io/badge/Terraform-≥_1.5-623CE4.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2_|_CloudFront-orange.svg)](https://aws.amazon.com/)

---

## 📋 Overview

This Terraform module deploys a fully-functional [CTFd](https://ctfd.io/) instance — the most popular open-source Capture The Flag platform — on a single EC2 instance fronted by CloudFront.

Everything is automated: from the OS bootstrap (Docker + CTFd + Docker Compose) to the networking (CloudFront origin lock, SSH key generation, Elastic IP). The entire stack is defined as code.

---

## 🏗️ Architecture

```
                    ┌──────────────────┐
                    │   CloudFront     │
                    │  (HTTPS + cache) │
                    └────────┬─────────┘
                             │ :8000 (origin)
                    ┌────────▼─────────┐
                    │  Security Group  │
                    │  CloudFront IPs  │
                    │  only + SSH CIDR │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐  ┌─────▼─────┐  ┌────▼────┐
        │  CTFd App │  │   MySQL   │  │  Redis  │
        │  :8000    │  │  :3306    │  │  :6379  │
        └───────────┘  └───────────┘  └─────────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼─────────┐
                    │  Docker Compose  │
                    │  (single EC2)    │
                    └──────────────────┘
```

---

## 🚀 Deployment

### 1. Initialize

```bash
cd ctfd-platform
terraform init
```

### 2. Review the plan

```bash
terraform plan
```

### 3. Deploy

```bash
terraform apply
```

Terraform will:
- Generate an RSA 4096-bit SSH key pair
- Launch a `t3.medium` EC2 instance with Amazon Linux 2023
- Bootstrap Docker, Docker Compose, and CTFd via `user_data.sh`
- Allocate and attach an Elastic IP
- Create a CloudFront distribution pointing to the instance
- Lock down the security group to CloudFront origin IPs only

### 4. Get the URL

```bash
terraform output cloudfront_url
# => https://d12345abcdef.cloudfront.net
```

Share this URL with CTF participants. CTFd will be live within 2-3 minutes of the instance booting.

### 5. SSH Access (if needed)

```bash
terraform output ssh_command
# => ssh -i ctfd-key.pem ec2-user@<EIP>
```

---

## 🔧 Configuration

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `ap-south-1` | AWS region |
| `instance_type` | `t3.medium` | EC2 instance type |
| `ssh_allowed_cidr` | `0.0.0.0/0` | CIDR allowed to SSH (lock down in prod) |
| `environment` | `ctf` | Environment tag |

Override via `terraform.tfvars` or `-var`:

```bash
terraform apply -var 'instance_type=t3.large' -var 'ssh_allowed_cidr=203.0.113.0/24'
```

---

## 📦 What `user_data.sh` Does

1. Updates system packages (`dnf update -y`)
2. Installs Docker and enables it at boot
3. Installs Docker Compose v2 plugin
4. Clones [CTFd/CTFd](https://github.com/CTFd/CTFd) to `/opt/ctfd`
5. Generates a random 64-character `SECRET_KEY`
6. Creates a `docker-compose.override.yml` injecting the secret
7. Starts the full CTFd stack (app + MySQL + Redis)

CTFd uses its built-in `docker-compose.yml` which includes all three services.

---

## 🔐 Security Design

| Layer | Mechanism |
|---|---|
| **Edge** | CloudFront provides HTTPS, DDoS protection, and caching |
| **Network** | Security group allows port 8000 only from CloudFront origin-facing IP prefix list |
| **SSH** | Auto-generated RSA 4096-bit key, private key written with `0400` permissions |
| **App** | Random 64-char `SECRET_KEY` generated at boot, never stored in code |
| **State** | Remote state in S3 with encryption and DynamoDB locking |

---

## 🧹 Teardown

```bash
terraform destroy
```

This removes all resources including the EC2 instance, EIP, CloudFront distribution, and security group. The local `ctfd-key.pem` file is not deleted by Terraform — remove it manually if no longer needed.

---

## 📝 Notes

- CloudFront deployment takes 5-10 minutes on first apply. Subsequent applies are faster.
- The EC2 instance uses the **default VPC** and the first available subnet. For production, consider a dedicated VPC.
- CTFd data (challenges, users, scores) lives in the Docker MySQL container on the EC2 instance. Back up the instance or mount an EBS volume for persistence across redeploys.
- The `.terraform.lock.hcl` file pins provider versions for reproducible deployments.

---

## 📄 License

MIT © Gul Tandon
