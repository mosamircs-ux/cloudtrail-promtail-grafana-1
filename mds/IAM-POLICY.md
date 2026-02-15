# IAM Policy for CloudTrail S3 Access

## Required IAM Policy

Attach this policy to the IAM role assigned to EC2 #1 (CloudTrail Processor):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudTrailS3ReadAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR-CLOUDTRAIL-BUCKET-NAME",
        "arn:aws:s3:::YOUR-CLOUDTRAIL-BUCKET-NAME/*"
      ]
    },
    {
      "Sid": "CloudTrailValidation",
      "Effect": "Allow",
      "Action": [
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR-CLOUDTRAIL-BUCKET-NAME/*"
      ]
    }
  ]
}
```

## Steps to Apply

### Option 1: Using AWS Console

1. Go to **IAM Console** → **Roles**
2. Find the role attached to EC2 #1
3. Click **Add permissions** → **Create inline policy**
4. Choose **JSON** tab
5. Paste the policy above (replace `YOUR-CLOUDTRAIL-BUCKET-NAME`)
6. Click **Review policy**
7. Name it: `CloudTrailS3ReadAccess`
8. Click **Create policy**

### Option 2: Using AWS CLI

```bash
# Replace with your values
ROLE_NAME="your-ec2-role-name"
BUCKET_NAME="your-cloudtrail-bucket-name"

# Create policy document
cat > /tmp/cloudtrail-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudTrailS3ReadAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    },
    {
      "Sid": "CloudTrailValidation",
      "Effect": "Allow",
      "Action": [
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF

# Attach policy to role
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name CloudTrailS3ReadAccess \
  --policy-document file:///tmp/cloudtrail-policy.json
```

## Verify IAM Role

On EC2 #1, run:

```bash
# Check current role
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://YOUR-CLOUDTRAIL-BUCKET-NAME/

# Test reading a file
aws s3 cp s3://YOUR-CLOUDTRAIL-BUCKET-NAME/AWSLogs/ - --recursive --max-items 1
```

## Security Best Practices

1. **Least Privilege**: Only grant read access to CloudTrail bucket
2. **No Access Keys**: Use IAM roles instead of hardcoded credentials
3. **Resource Restrictions**: Limit to specific bucket only
4. **VPC Endpoint**: Use S3 VPC endpoint to avoid internet traffic
5. **Encryption**: Ensure CloudTrail logs are encrypted at rest

## Troubleshooting

### Access Denied Error

```bash
# Check if role is attached
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Check role permissions
aws iam get-role-policy --role-name YOUR-ROLE-NAME --policy-name CloudTrailS3ReadAccess
```

### No Role Attached

If EC2 doesn't have an IAM role:

1. Go to **EC2 Console**
2. Select your instance
3. **Actions** → **Security** → **Modify IAM role**
4. Select or create a role with the policy above
5. Click **Update IAM role**
6. Restart the CloudTrail processor service:
   ```bash
   sudo systemctl restart cloudtrail-processor
   ```
