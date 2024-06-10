# 🪣 S3 CTF — "Glistening Oasis"

> A beginner-friendly AWS S3 misconfiguration challenge teaching bucket enumeration, versioning, and data recovery.

[![Difficulty](https://img.shields.io/badge/difficulty-easy-brightgreen.svg)]()
[![Category](https://img.shields.io/badge/category-cloud_|_AWS-blue.svg)]()
[![Terraform](https://img.shields.io/badge/Terraform-≥_1.5-623CE4.svg)](https://www.terraform.io/)

---

## 📋 Overview

**"Glistening Oasis"** is a Capture The Flag challenge that simulates a real-world S3 data exposure scenario. Players are given a URL to an internal portal page and must use S3 enumeration techniques to discover and recover a deleted flag hidden in the bucket's version history.

The challenge teaches:

| Concept | Technique |
|---|---|
| S3 static website URL format | Extract bucket name and region from the URL |
| S3 REST API enumeration | `?list-type=2` to discover hidden files |
| S3 versioning | `?versions` to find deleted objects and delete markers |
| Version ID retrieval | `?versionId=<id>` to fetch deleted data |
| Bucket policy exploitation | Understanding public `s3:ListBucketVersions` |

---

## 🎯 Challenge Flow

```
Player visits website URL
        │
        ▼
┌───────────────────┐
│  index.html       │  ← "look around, explore what's nearby"
│  (static portal)  │
└──────┬────────────┘
       │ ?list-type=2
       ▼
┌───────────────────┐
│  Bucket listing   │  ← discovers hint.txt
│  (XML)            │
└──────┬────────────┘
       │ GET hint.txt
       ▼
┌───────────────────┐
│  hint.txt         │  ← "files removed, versions retained, check history"
│  (internal memo)  │
└──────┬────────────┘
       │ ?versions
       ▼
┌───────────────────┐
│  Version listing  │  ← discovers deleted flag.txt with version ID
│  (XML)            │
└──────┬────────────┘
       │ ?versionId=<id>
       ▼
   ┌───────┐
   │ FLAG! │  🎉
   └───────┘
```

---

## 🚀 Deployment

### 1. Initialize

```bash
cd s3-ctf
terraform init
```

### 2. Deploy with a custom flag

```bash
terraform apply -var 'flag_content=CTF{your_custom_flag_here}'
```

> **Important:** Always pass the flag at apply time. The default flag in `variables.tf` is public in the repo.

### 3. Get the challenge URL

```bash
terraform output website_url
# => http://ctf-web-allowing-grouper.s3-website.ap-south-1.amazonaws.com
```

Share this URL with players — it's the starting point.

---

## 🧩 How It Works

### The Flag Trick

The challenge uses a `null_resource` with `local-exec` to create the core puzzle:

1. **Upload** `flag.txt` to the S3 bucket (version V1 is created)
2. **Delete** `flag.txt` (places a delete marker on top)

The bucket has:
- **Versioning enabled** — V1 is retained even after deletion
- **`s3:ListBucketVersions` public** — anyone can enumerate versions
- **`s3:GetObjectVersion` public** — anyone can fetch a specific version by ID

This means the flag is "deleted" from the normal object listing but fully recoverable by anyone who knows to check the version history.

### Static Files

| File | Purpose |
|---|---|
| `index.html` | Dark-themed corporate portal page with subtle hints |
| `hint.txt` | In-universe memo hinting at version retention |

Both are uploaded as S3 objects and served via the static website endpoint.

---

## 🔧 Configuration

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `ap-south-1` | AWS region |
| `flag_content` | `CTF{s3_v3rs10n_h1st0ry_n3v3r_l13s}` | The flag (override at apply time!) |
| `environment` | `ctf` | Environment tag |

---

## 🧪 Testing the Challenge

After deployment, verify the challenge works:

```bash
BUCKET="ctf-web-<random-suffix>"
REGION="ap-south-1"

# 1. Visit the website
curl "http://${BUCKET}.s3-website.${REGION}.amazonaws.com/"

# 2. List bucket contents
curl "https://${BUCKET}.s3.${REGION}.amazonaws.com/?list-type=2"

# 3. Read hint.txt
curl "https://${BUCKET}.s3.${REGION}.amazonaws.com/hint.txt"

# 4. List versions (includes delete markers)
curl "https://${BUCKET}.s3.${REGION}.amazonaws.com/?versions"

# 5. Extract the versionId of flag.txt from the XML, then:
curl "https://${BUCKET}.s3.${REGION}.amazonaws.com/flag.txt?versionId=<id>"
```

---

## 🧹 Teardown

```bash
terraform destroy
```

The bucket uses `force_destroy = true` so all versioned objects (including the delete marker and retained flag) are purged automatically.

---

## 🔐 Security Notes

- **The bucket is intentionally public.** This is the challenge — don't deploy this in a production AWS account without understanding the implications.
- **The default flag is in the repo.** Anyone with source access knows the answer. Always override with `-var 'flag_content=...'`.
- **`null_resource` + `local-exec` requires AWS CLI.** The flag upload/delete trick uses the AWS CLI on the local machine. Ensure it's installed and configured.
- **Tear down after the event.** Leaving a public versioned bucket running exposes it to abuse.

---

## 📚 Further Reading

- [`spec.txt`](spec.txt) — Original challenge specification
- [`writeup.md`](writeup.md) — Full step-by-step solution with screenshots and XML examples
- [`interview-prep.md`](interview-prep.md) — Project critique, security analysis, and interview Q&A

---

## 📄 License

MIT © Gul Tandon
