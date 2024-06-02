# Interview Prep: Glistening Oasis S3 CTF

## Project Critique

### Strengths

**Challenge design is tight.**
Each step creates a natural breadcrumb — the URL reveals the bucket name and region, the listing reveals `hint.txt`, the hint points at versioning, and versioning reveals the deleted flag. No step feels arbitrary.

**Realistic misconfiguration scenario.**
The challenge mirrors a real-world cloud incident pattern: an operator "deletes" a sensitive file from a public bucket, assumes it's gone, but S3 versioning silently retained it. This is a documented AWS security issue seen in actual breach investigations.

**Terraform is clean and well-structured.**
Good separation across `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf`. The `random_pet` suffix avoids bucket name collisions across deployments. `force_destroy = true` is essential here since versioned objects would otherwise block `terraform destroy`. The `depends_on` on the bucket policy is correct — the public access block must be cleared before the policy can be applied.

**`s3:GetObjectVersion` in the bucket policy is intentional and correct.**
This is a separate IAM action from `s3:GetObject` — it explicitly grants access to retrieve specific object versions by version ID, which is the mechanic players need to fetch the deleted flag.

---

### Weaknesses

**1. Flag is hardcoded in `variables.tf` as the default.**
`sensitive = true` prevents it from appearing in `terraform plan` output and state display, but the value is plaintext in the repo. Anyone with the source code can read the flag without solving the challenge. For a real deployment, the flag should be supplied at apply time:

```
terraform apply -var 'flag_content=CTF{...}'
```

or via a `.tfvars` file that is gitignored.

**2. `null_resource` + `local-exec` is fragile.**
This depends on the local machine having the AWS CLI installed, configured, and using the right profile. It's not portable — someone running this in a CI environment or on a different machine may hit auth or path issues. A purpose-built Terraform resource (e.g., `aws_s3_object` with a lifecycle + explicit version management, or a custom Lambda-backed provider) would be more reproducible, though admittedly more complex.

**3. Potential shell injection in `local-exec`.**
```hcl
printf '%s\n' '${var.flag_content}' > "$TMPFILE"
```
If `flag_content` contains a single quote, the shell command breaks. For a CTF with a controlled flag value this is low risk, but it's worth noting as a habit.

**4. Writeup has an inconsistency.**
Step 4 prose says "version `oAt3r8hiSELjG2RfT17B6i.YvxJJiCBS` still exists" but the XML example in the same step shows `1dSjM13ytePvIfld2vIfBlbX035ZvwHZ`. The two version IDs don't match. Looks like a copy-paste error from an earlier draft.

**5. No lifecycle policy.**
Old object versions accumulate indefinitely. For the challenge this is intentional (the delete marker is the mechanic), but if the bucket were re-deployed with a different flag, the previous flag version would still be recoverable. Scoping the lifecycle or rotating the bucket entirely on each deployment would prevent cross-run leakage.

**6. S3 static website hosting is HTTP only.**
S3 website endpoints don't support HTTPS without a CloudFront distribution in front. For a CTF this is fine, but it's worth knowing if asked about hardening.

---

---

## Interview Questions & Ideal Answers

---

### AWS S3 Concepts

**Q1. What is the difference between the S3 static website endpoint and the S3 REST API endpoint?**

The website endpoint (`<bucket>.s3-website.<region>.amazonaws.com`) is designed for browser hosting — it serves `index.html` for root requests, handles custom error pages, and only supports HTTP. It does not return XML listings.

The REST endpoint (`<bucket>.s3.<region>.amazonaws.com`) is the raw API surface. It supports all S3 API operations including `?list-type=2` for bucket listings, `?versions` for version listings, and `?versionId=` for fetching specific object versions. This is the endpoint the challenge exploits.

---

**Q2. What is S3 versioning and what happens when you "delete" a versioned object?**

S3 versioning keeps every version of every object ever written to a bucket. When you delete an object in a versioned bucket without specifying a version ID, S3 doesn't remove any data — it instead creates a **delete marker**, which is a zero-byte placeholder with its own version ID. The delete marker becomes the "latest" version, so normal `GET` requests return a 404. But all previous versions still exist and are directly accessible by their version ID.

To permanently remove data from a versioned bucket, you must explicitly delete each version (including delete markers) by version ID. This is what makes versioned public buckets dangerous: operators often don't realize the data is still there.

---

**Q3. How did you expose the deleted `flag.txt` to unauthenticated users? Walk me through the bucket policy.**

The bucket policy has two statements. The first grants `s3:GetObject` and `s3:GetObjectVersion` on `arn:...:bucket/*` to `Principal: "*"` — this allows anyone to download any object, including fetching a specific version by ID. The second grants `s3:ListBucket` and `s3:ListBucketVersions` on the bucket ARN itself (not the objects) — this allows anyone to run `?list-type=2` and `?versions` queries and see the full object inventory including delete markers and version IDs.

Without `s3:ListBucketVersions`, players wouldn't be able to discover the version ID of the deleted flag — they'd need to already know it.

---

**Q4. Why must `aws_s3_bucket_public_access_block` be configured before the bucket policy, and how did you handle that in Terraform?**

AWS's "block public access" feature at the bucket level acts as an override that can reject public bucket policies regardless of what the policy says. If you try to apply a public-allow bucket policy while `block_public_policy` is still `true`, the API call will fail with an access denied error.

In the Terraform code, `aws_s3_bucket_policy.website` has an explicit `depends_on = [aws_s3_bucket_public_access_block.website]` to ensure the block is cleared first. Without this, Terraform might apply the policy and the access block in parallel and hit a race condition.

---

**Q5. What does `force_destroy = true` on the S3 bucket do, and why is it necessary here?**

By default, Terraform refuses to delete an S3 bucket that contains objects. `force_destroy = true` tells Terraform to empty the bucket (delete all objects and all versions) before destroying it. Without it, `terraform destroy` would fail because the bucket contains versioned objects including the delete marker and the retained `flag.txt` version. For a CTF environment that gets torn down and rebuilt frequently, this is the right setting.

---

### Terraform Concepts

**Q6. Why did you use `null_resource` with `local-exec` for the flag upload instead of `aws_s3_object`?**

`aws_s3_object` manages an object's current (latest) version. There's no native Terraform resource that uploads a file and then immediately deletes it to create a delete marker — that's a two-step stateful operation outside Terraform's resource model. Using `null_resource` with `local-exec` lets me script the `put-object` + `delete-object` sequence via the AWS CLI, which achieves the exact S3 state the challenge requires: a retained old version with a delete marker on top.

The tradeoff is that it introduces a dependency on the local machine having the AWS CLI installed and configured, making it less portable than pure Terraform.

---

**Q7. How do `triggers` on a `null_resource` work?**

`null_resource` has no actual infrastructure state — Terraform considers it "done" once the provisioner runs. The `triggers` map is used as a proxy for change detection: if any value in the map changes between runs, Terraform marks the `null_resource` as tainted and re-runs the provisioner on the next `apply`. In this case, the triggers are `bucket_name`, `flag_content`, and `region` — so if the flag is rotated, the provisioner re-runs and uploads + deletes the new flag.

---

**Q8. What is `random_pet` and why use it here?**

`random_pet` from the HashiCorp `random` provider generates a random human-readable name like `allowing-grouper`. S3 bucket names are globally unique across all AWS accounts — if you hardcode a name and someone else already has that bucket, the deployment fails. Using a random suffix ensures the bucket name is unique on every deployment without requiring manual input. It also makes the URL less predictable, which in a CTF context is intentional: the URL being the starting clue requires players to actually look at it.

---

### Cloud Security Concepts

**Q9. This challenge exposes a public S3 bucket intentionally. What would you do in a real environment to prevent this misconfiguration?**

Several layers:

- **Account-level S3 Block Public Access** — AWS has a setting at the account level (not just bucket level) that blocks any public bucket policy or ACL. Enabling this account-wide makes it impossible to accidentally expose buckets.
- **AWS Config rule `s3-bucket-public-read-prohibited`** — continuously monitors for public buckets and flags violations.
- **SCPs (Service Control Policies) in AWS Organizations** — can deny `s3:PutBucketPolicy` calls that contain `"Principal": "*"` entirely, preventing the misconfiguration at the IAM control plane level.
- **Versioning + lifecycle policies** — if versioning is needed, pair it with an Object Lifecycle Policy that expires non-current versions after N days, so old versions don't accumulate indefinitely.
- **CloudTrail** — log all S3 data events to detect unexpected access patterns.

---

**Q10. What real-world security incident does this challenge simulate?**

This mirrors a common class of AWS data exposure incident. A developer or operator uploads a sensitive file to an S3 bucket for testing, then "deletes" it assuming it's gone. But if the bucket has versioning enabled and is publicly accessible, the file persists as a retained version. Security researchers routinely discover sensitive data (credentials, PII, internal documents) via S3 version history enumeration on misconfigured buckets. Notable historical examples include misconfigured buckets belonging to large enterprises where "deleted" files were recovered months later.

---

**Q11. Why is `s3:ListBucketVersions` a particularly sensitive permission to grant publicly?**

`s3:ListBucketVersions` exposes the full version history of every object in the bucket, including delete markers. Without it, an attacker would need to already know the exact version ID of a deleted object to retrieve it — essentially a secret. With it, they can enumerate all version IDs of all objects, including ones that were "deleted," and then fetch them directly. It turns a theoretical exposure (guessing a version ID) into a practical one (knowing exactly what to fetch).

---

### Challenge Design

**Q12. How does the hint.txt contribute to the challenge without giving it away?**

`hint.txt` acts as an in-world lore document — it mimics a corporate memo about a "storage cleanup." It tells players two things without using technical jargon: files have been removed, and all versions are retained per a data retention policy. A player who understands S3 versioning immediately knows what to do. A player who doesn't is pointed at the right concept ("check the full version history") without being handed the exact API query. It keeps the challenge accessible while preserving the learning objective.

---

**Q13. What would you add to make this challenge harder?**

A few options:

- **Remove `s3:ListBucketVersions` from the public policy.** Players would need to find the version ID another way — perhaps the version ID is embedded in a comment in `index.html`, or referenced in a second bucket that requires the same enumeration technique to find.
- **Add a second bucket.** The first bucket's `hint.txt` contains the name of a second (private) bucket. Players must figure out they have a role or STS token (maybe embedded in the HTML source) to access it, teaching IAM credential misuse.
- **Add SSRF or metadata service.** Introduce a server-side component (Lambda function URL) that is vulnerable to SSRF, allowing players to hit the EC2 instance metadata endpoint and retrieve temporary credentials. This extends the challenge into IAM privilege escalation.
- **Encrypt the flag at rest** with a KMS key that's publicly accessible but requires understanding KMS policy syntax to use.

---

**Q14. The flag is hardcoded as the default value in `variables.tf`. What's the security issue and how would you fix it?**

`sensitive = true` in Terraform prevents the value from appearing in plan/apply output and marks it as redacted in state display, but it does not encrypt the value in the state file or prevent it from appearing in source code. The flag is plaintext in the repo, meaning anyone with read access to the repository already knows the answer.

The fix is to remove the `default` from the variable and require it to be passed at apply time:

```
terraform apply -var 'flag_content=CTF{...}'
```

Or use a `.tfvars` file that is `.gitignore`d. For sensitive production values, the correct pattern is to source them from a secrets manager (AWS Secrets Manager, HashiCorp Vault) via a data source, never hardcode them.
