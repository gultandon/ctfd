# Writeup: Glistening Oasis

**Category:** Cloud / AWS  
**Difficulty:** Easy  

---

## Challenge Description

> You've been given access to the Glistening Oasis internal portal. Find the flag.
>
> http://ctf-web-allowing-grouper.s3-website.ap-south-1.amazonaws.com

---

## Step 1 — Visit the Website

Opening the URL in a browser shows a simple internal portal page.

```
Glistening Oasis Internal Portal
v1.0.3 — last updated 2024-11-14

Welcome to the internal resource portal for Project Glistening Oasis.
If you are seeing this page, you have been granted access to this environment.

NOTICE: This portal is under construction...

In the meantime, feel free to look around. Everything you need has already
been placed in this environment.

If you are lost, start by examining where you are — then explore what else
might be nearby.
```

The page itself isn't very useful, but the **URL is the first hint**. Look at it carefully:

```
http://ctf-web-allowing-grouper.s3-website.ap-south-1.amazonaws.com
```

The domain pattern `<bucket>.s3-website.<region>.amazonaws.com` is the S3 static website hosting endpoint format. This tells us the page is hosted directly from an **AWS S3 bucket** named `ctf-web-allowing-grouper` in region `ap-south-1`.

---

## Step 2 — List the S3 Bucket

S3 buckets can be queried directly via the REST API endpoint, which is different from the website endpoint. The REST endpoint has the form:

```
https://<bucket>.s3.<region>.amazonaws.com/
```

When a bucket has public `s3:ListBucket` permissions, navigating to it with a list query returns an XML document of all objects inside. Try:

```
https://ctf-web-allowing-grouper.s3.ap-south-1.amazonaws.com/?list-type=2
```

The response is an XML document listing the bucket contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult>
  <Name>ctf-web-allowing-grouper</Name>
  ...
  <Contents>
    <Key>hint.txt</Key>
    ...
  </Contents>
  <Contents>
    <Key>index.html</Key>
    ...
  </Contents>
</ListBucketResult>
```

Two files: `index.html` (the page we already saw) and `hint.txt`. No flag yet.

---

## Step 3 — Read hint.txt

Fetch `hint.txt` directly:

```
https://ctf-web-allowing-grouper.s3.ap-south-1.amazonaws.com/hint.txt
```

Contents:

```
[INTERNAL MEMO]
Subject: Storage Cleanup Notice

A routine cleanup pass has been run on this environment.
Some files have been removed from the active listing.

Per our data retention policy, storage compliance requires that all
previous versions of objects be retained indefinitely.

If you are looking for a file that is no longer visible, check the
full version history of this bucket.

- Ops
```

Key takeaways:
- Files have been **removed from the active listing** (deleted)
- But **all versions are retained** (versioning is enabled)
- We should check the **version history**

---

## Step 4 — List Object Versions

S3 versioning keeps a full history of every object, including deleted ones. A deleted object gets a **delete marker** placed on top of it — the object disappears from normal listings but its previous versions still exist and are downloadable by version ID.

To list all versions (including delete markers), append `?versions` to the REST endpoint:

```
https://ctf-web-allowing-grouper.s3.ap-south-1.amazonaws.com/?versions
```

The XML response now includes a `<DeleteMarkers>` section and a `<Version>` entry that wasn't visible before:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ListVersionsResult>
  <Name>ctf-web-allowing-grouper</Name>
  ...

  <!-- The actual file, still stored as version V1 -->
  <Version>
    <Key>flag.txt</Key>
    <VersionId>1dSjM13ytePvIfld2vIfBlbX035ZvwHZ</VersionId>
    <IsLatest>false</IsLatest>
    <LastModified>2026-04-26T10:25:48+00:00</LastModified>
    ...
  </Version>

  <!-- The delete marker placed on top, making it "disappear" from normal listings -->
  <DeleteMarker>
    <Key>flag.txt</Key>
    <VersionId>S0kDVujjtXuqs9B2hbSWtuKA3SPgKmdn</VersionId>
    <IsLatest>true</IsLatest>
    <LastModified>2026-04-26T10:25:49+00:00</LastModified>
  </DeleteMarker>

  ...
</ListVersionsResult>
```

We can see `flag.txt` was deleted (the delete marker is `IsLatest: true`), but **version `oAt3r8hiSELjG2RfT17B6i.YvxJJiCBS` still exists**.

---

## Step 5 — Download the Deleted flag.txt

To fetch a specific version of an object, append `?versionId=<id>` to the object URL:

```
https://ctf-web-allowing-grouper.s3.ap-south-1.amazonaws.com/flag.txt?versionId=1dSjM13ytePvIfld2vIfBlbX035ZvwHZ
```

This returns the original contents of `flag.txt`:

```
CTF{s3_v3rs10n_h1st0ry_n3v3r_l13s}
```

---

## Flag

```
CTF{s3_v3rs10n_h1st0ry_n3v3r_l13s}
```

---

## Key Concepts

| Concept | What it taught |
|---|---|
| S3 static website URL format | Reveals bucket name and region from the URL itself |
| S3 REST endpoint vs website endpoint | `?list-type=2` on REST endpoint returns XML bucket listing |
| S3 `s3:ListBucket` permission | Allows unauthenticated enumeration of bucket contents |
| S3 versioning | Deleted objects aren't gone — they get a delete marker |
| `?versions` query | Lists full version history including delete markers |
| `?versionId=<id>` | Retrieves a specific version, even after deletion |

The lesson: **deleting a file from a versioned S3 bucket does not destroy it.** The data persists until all versions are explicitly purged. Misconfigured public buckets with versioning enabled can expose data even after an operator believes it has been removed.
