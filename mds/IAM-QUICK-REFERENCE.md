# IAM Policy Quick Reference

## ✅ What You Need

**Only S3 read access to CloudTrail bucket!**

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b",
      "arn:aws:s3:::aws-cloudtrail-logs-124737196430-56a3b94b/*"
    ]
  }]
}
```

## ❌ What You DON'T Need

- ❌ `ec2:Describe*` - Already in CloudTrail logs!
- ❌ `s3:List*` (all buckets) - Only need one bucket!
- ❌ `rds:Describe*` - Already in CloudTrail logs!
- ❌ `iam:Get*` - Already in CloudTrail logs!
- ❌ `lambda:*` - Already in CloudTrail logs!

## 🚀 Quick Setup

### Option 1: Automated Script (Easiest)

```bash
# Upload script to your local machine
# Run from your local machine (not EC2):
chmod +x setup-iam-role.sh
./setup-iam-role.sh

# Enter your EC2 instance ID when prompted
```

### Option 2: AWS Console (Manual)

1. **Create Policy:** IAM → Policies → Create → Paste JSON above
2. **Create Role:** IAM → Roles → Create → EC2 → Attach policy
3. **Attach to EC2:** EC2 Console → Instance → Actions → Security → Modify IAM Role

### Option 3: AWS CLI (Manual)

```bash
# Create policy
aws iam create-policy \
  --policy-name CloudTrailProcessorS3ReadOnly \
  --policy-document file://iam-policy-minimal.json

# Create role
aws iam create-role \
  --role-name EC2-CloudTrailProcessor-Role \
  --assume-role-policy-document file://ec2-trust-policy.json

# Attach policy to role (replace ACCOUNT_ID)
aws iam attach-role-policy \
  --role-name EC2-CloudTrailProcessor-Role \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/CloudTrailProcessorS3ReadOnly

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name EC2-CloudTrailProcessor-Profile

# Add role to profile
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2-CloudTrailProcessor-Profile \
  --role-name EC2-CloudTrailProcessor-Role

# Attach to EC2 (replace INSTANCE_ID)
aws ec2 associate-iam-instance-profile \
  --instance-id i-YOURINSTANCEID \
  --iam-instance-profile Name=EC2-CloudTrailProcessor-Profile
```

## 🧪 Verify

```bash
# SSH to EC2 and test S3 access
aws s3 ls s3://aws-cloudtrail-logs-124737196430-56a3b94b/AWSLogs/ --region me-south-1

# Should work! ✅

# This should fail (expected!)
aws ec2 describe-instances --region me-south-1
# ❌ Error: UnauthorizedOperation (This is correct!)
```

## 📁 Files

- `iam-policy-minimal.json` - The minimal policy
- `ec2-trust-policy.json` - Trust policy for EC2
- `setup-iam-role.sh` - Automated setup script
- `IAM-POLICY-GUIDE.md` - Complete documentation

## 💡 Why So Minimal?

CloudTrail logs **already contain**:
- ✅ All resource IDs (EC2, S3, RDS, Lambda, etc.)
- ✅ All access key information
- ✅ All user identity details
- ✅ Request and response data

**You don't need to call AWS APIs** - just read the logs!

## 🔒 Security Note

This is **least privilege** - only grants what's absolutely necessary:
- ✓ Read access to one specific S3 bucket
- ✓ No write permissions
- ✓ No access to other AWS services
- ✓ Uses IAM role (not access keys)

---

**See IAM-POLICY-GUIDE.md for complete documentation!**
