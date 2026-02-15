# IAM Role Policy for CloudTrail Processor

## Overview

Your EC2 instance running the CloudTrail processor needs an IAM role with permissions to:
1. **Read CloudTrail logs from S3** (required for basic operation)
2. **NO additional AWS API permissions needed!** (CloudTrail logs already contain all info)

## Important: CloudTrail Already Has Everything!

**Good news:** CloudTrail events already contain:
- ✅ All resource identifiers (EC2 instance IDs, S3 buckets, etc.)
- ✅ All access key information (including session context)
- ✅ All user identity details
- ✅ Request and response elements

You **DO NOT** need permissions to call AWS APIs (like `ec2:DescribeInstances`) because CloudTrail already logged that information!

---

## Minimal IAM Policy (Recommended)

This is the **minimum required** policy for the CloudTrail processor:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadCloudTrailLogsFromS3",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b",
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b/*"
      ]
    }
  ]
}
```

**That's it!** This is all you need.

---

## Why No Additional Permissions Are Needed

### ❌ You DON'T Need These (Common Misconception):

```json
// NOT NEEDED - CloudTrail already logged this info!
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeInstances",        // ❌ NOT NEEDED
    "ec2:DescribeVolumes",           // ❌ NOT NEEDED
    "s3:ListAllMyBuckets",           // ❌ NOT NEEDED
    "rds:DescribeDBInstances",       // ❌ NOT NEEDED
    "lambda:ListFunctions",          // ❌ NOT NEEDED
    "iam:GetUser",                   // ❌ NOT NEEDED
    "iam:GetRole"                    // ❌ NOT NEEDED
  ],
  "Resource": "*"
}
```

### ✅ Why CloudTrail Logs Are Self-Sufficient

When someone (using access key `AKIAIOSFODNN7EXAMPLE`) performs an action like:

```bash
aws ec2 describe-instances --instance-ids i-0abc123
```

CloudTrail logs an event that contains:
```json
{
  "eventName": "DescribeInstances",
  "userIdentity": {
    "type": "IAMUser",
    "accessKeyId": "AKIAIOSFODNN7EXAMPLE",  ← Already in the log!
    "arn": "arn:aws:iam::123456789:user/john"
  },
  "requestParameters": {
    "instancesSet": {
      "items": [
        {"instanceId": "i-0abc123"}  ← Already in the log!
      ]
    }
  },
  "responseElements": {
    "reservationSet": {
      "items": [{
        "instancesSet": {
          "items": [{
            "instanceId": "i-0abc123",  ← Already in the log!
            "instanceType": "t3.medium",
            "privateIpAddress": "10.0.1.5"
          }]
        }
      }]
    }
  }
}
```

**Everything is already there!** The processor just reads and parses it.

---

## Complete IAM Setup Guide

### Option 1: Using AWS Console (Recommended)

#### Step 1: Create IAM Policy

1. Go to **IAM Console** → **Policies** → **Create Policy**
2. Click **JSON** tab
3. Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadCloudTrailLogsFromS3",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b",
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b/*"
      ]
    }
  ]
}
```

4. Click **Next: Tags** (skip tags)
5. Click **Next: Review**
6. **Name:** `CloudTrailProcessorS3ReadOnly`
7. **Description:** `Allows reading CloudTrail logs from S3 for Promtail processor`
8. Click **Create Policy**

#### Step 2: Create IAM Role

1. Go to **IAM Console** → **Roles** → **Create Role**
2. Select **AWS Service** → **EC2**
3. Click **Next: Permissions**
4. Search for `CloudTrailProcessorS3ReadOnly` (the policy you just created)
5. Check the box next to it
6. Click **Next: Tags** (skip tags)
7. Click **Next: Review**
8. **Role Name:** `EC2-CloudTrailProcessor-Role`
9. **Description:** `Allows EC2 instance to read CloudTrail logs from S3`
10. Click **Create Role**

#### Step 3: Attach Role to EC2 Instance

1. Go to **EC2 Console** → **Instances**
2. Select your Promtail/Processor EC2 instance
3. Click **Actions** → **Security** → **Modify IAM Role**
4. Select `EC2-CloudTrailProcessor-Role`
5. Click **Update IAM Role**

---

### Option 2: Using AWS CLI

```bash
# Step 1: Create the IAM policy
cat > cloudtrail-processor-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadCloudTrailLogsFromS3",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b",
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b/*"
      ]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name CloudTrailProcessorS3ReadOnly \
  --policy-document file://cloudtrail-processor-policy.json

# Step 2: Create trust policy for EC2
cat > ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Step 3: Create IAM role
aws iam create-role \
  --role-name EC2-CloudTrailProcessor-Role \
  --assume-role-policy-document file://ec2-trust-policy.json

# Step 4: Attach policy to role (replace ACCOUNT_ID with your account)
aws iam attach-role-policy \
  --role-name EC2-CloudTrailProcessor-Role \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/CloudTrailProcessorS3ReadOnly

# Step 5: Create instance profile
aws iam create-instance-profile \
  --instance-profile-name EC2-CloudTrailProcessor-Profile

# Step 6: Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2-CloudTrailProcessor-Profile \
  --role-name EC2-CloudTrailProcessor-Role

# Step 7: Attach instance profile to EC2 (replace INSTANCE_ID)
aws ec2 associate-iam-instance-profile \
  --instance-id i-YOURINSTANCEID \
  --iam-instance-profile Name=EC2-CloudTrailProcessor-Profile
```

---

## Optional: Enhanced Policy with Additional Features

If you want to add **future-proofing** or **additional features**, here's an enhanced policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadCloudTrailLogsFromS3",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b",
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b/*"
      ]
    },
    {
      "Sid": "AllowGetBucketLocation",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b"
    },
    {
      "Sid": "AllowCloudWatchLogsForMonitoring",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/ec2/cloudtrail-processor:*"
    }
  ]
}
```

**What this adds:**
- `s3:GetBucketLocation` - Allows getting bucket region (useful if you have multi-region setup)
- CloudWatch Logs permissions - If you want to send processor logs to CloudWatch (optional)

---

## Security Best Practices

### ✅ DO:
1. **Use least privilege** - Only grant S3 read access to the CloudTrail bucket
2. **Restrict to specific bucket** - Don't use `Resource: "*"`
3. **Use IAM roles** - Don't use access keys on the EC2 instance
4. **Enable CloudTrail encryption** - Use KMS encryption for extra security

### ❌ DON'T:
1. **Don't grant `s3:*`** - Only need `GetObject` and `ListBucket`
2. **Don't use `Resource: "*"`** - Specify the exact bucket ARN
3. **Don't add unnecessary EC2/RDS/Lambda permissions** - Not needed!
4. **Don't store access keys** - Use IAM instance profile instead

---

## If Using KMS Encryption

If your CloudTrail bucket uses **KMS encryption**, add this to the policy:

```json
{
  "Sid": "AllowKMSDecryption",
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "arn:aws:kms:me-south-1:124737196430:key/YOUR-KMS-KEY-ID"
}
```

**To find your KMS key ID:**
```bash
aws s3api get-bucket-encryption \
  --bucket aws-cloudtrail-logs-124737196430-56a3b94b \
  --region me-south-1
```

---

## Verification

After attaching the IAM role to your EC2 instance:

### Test S3 Access

```bash
# SSH to your EC2 instance
ssh -i your-key.pem ubuntu@YOUR_EC2_IP

# Test S3 access (should work)
aws s3 ls s3://aws-cloudtrail-logs-124737196430-56a3b94b/AWSLogs/ \
  --region me-south-1

# Test getting a file (should work)
aws s3 cp \
  s3://aws-cloudtrail-logs-124737196430-56a3b94b/AWSLogs/124737196430/CloudTrail/me-south-1/2026/02/08/file.json.gz \
  /tmp/test.json.gz \
  --region me-south-1

# This should fail if you didn't add EC2 permissions (which is correct!)
aws ec2 describe-instances --region me-south-1
# Output: An error occurred (UnauthorizedOperation) when calling the DescribeInstances operation...
# ✅ This is expected and correct!
```

### Verify Processor Works

```bash
# Check if processor can read logs
sudo journalctl -u cloudtrail-processor -n 50 --no-pager

# Should see messages like:
# "Looking for logs since..."
# "Found X new log files"
# "Downloading s3://aws-cloudtrail-logs-..."
# "Successfully wrote X events"
```

---

## Summary

### Minimal Required Permissions

| Permission | Why Needed |
|------------|------------|
| `s3:GetObject` | Download CloudTrail log files |
| `s3:ListBucket` | List log files in the bucket |

### NOT Needed (Everything's in CloudTrail!)

| Permission | Why NOT Needed |
|------------|----------------|
| `ec2:Describe*` | ❌ Instance info already in CloudTrail logs |
| `s3:List*` (all buckets) | ❌ Only need one specific bucket |
| `rds:Describe*` | ❌ RDS info already in CloudTrail logs |
| `iam:Get*` | ❌ User/role info already in CloudTrail logs |
| `lambda:List*` | ❌ Lambda info already in CloudTrail logs |

### The Only IAM Policy You Need

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b",
        "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b/*"
      ]
    }
  ]
}
```

---

## Files Created

I'll create the policy files for you to use:
