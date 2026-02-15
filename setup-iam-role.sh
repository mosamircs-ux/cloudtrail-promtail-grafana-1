#!/bin/bash
# Setup IAM Role for CloudTrail Processor EC2 Instance
# This script creates the minimal IAM role needed for the processor to work

set -e

echo "=========================================="
echo "CloudTrail Processor IAM Setup"
echo "=========================================="
echo ""

# Configuration
BUCKET_NAME="aws-cloudtrail-logs-124737196430-56a3b94b"
POLICY_NAME="CloudTrailProcessorS3ReadOnly"
ROLE_NAME="EC2-CloudTrailProcessor-Role"
INSTANCE_PROFILE_NAME="EC2-CloudTrailProcessor-Profile"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo ""

# Step 1: Create IAM Policy
echo "Step 1: Creating IAM Policy..."
cat > /tmp/cloudtrail-processor-policy.json << EOF
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
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF

# Check if policy already exists
if aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" &>/dev/null; then
    echo "✓ Policy ${POLICY_NAME} already exists"
else
    POLICY_ARN=$(aws iam create-policy \
      --policy-name "${POLICY_NAME}" \
      --policy-document file:///tmp/cloudtrail-processor-policy.json \
      --description "Allows reading CloudTrail logs from S3" \
      --query 'Policy.Arn' \
      --output text)
    echo "✓ Created policy: ${POLICY_ARN}"
fi
echo ""

# Step 2: Create Trust Policy
echo "Step 2: Creating Trust Policy..."
cat > /tmp/ec2-trust-policy.json << 'EOF'
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
echo "✓ Trust policy created"
echo ""

# Step 3: Create IAM Role
echo "Step 3: Creating IAM Role..."
if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
    echo "✓ Role ${ROLE_NAME} already exists"
else
    aws iam create-role \
      --role-name "${ROLE_NAME}" \
      --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
      --description "Allows EC2 to read CloudTrail logs from S3" \
      &>/dev/null
    echo "✓ Created role: ${ROLE_NAME}"
fi
echo ""

# Step 4: Attach Policy to Role
echo "Step 4: Attaching policy to role..."
aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" \
  2>/dev/null || true
echo "✓ Policy attached to role"
echo ""

# Step 5: Create Instance Profile
echo "Step 5: Creating instance profile..."
if aws iam get-instance-profile --instance-profile-name "${INSTANCE_PROFILE_NAME}" &>/dev/null; then
    echo "✓ Instance profile ${INSTANCE_PROFILE_NAME} already exists"
else
    aws iam create-instance-profile \
      --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
      &>/dev/null
    echo "✓ Created instance profile: ${INSTANCE_PROFILE_NAME}"
fi
echo ""

# Step 6: Add Role to Instance Profile
echo "Step 6: Adding role to instance profile..."
aws iam add-role-to-instance-profile \
  --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
  --role-name "${ROLE_NAME}" \
  2>/dev/null || echo "✓ Role already added to instance profile"
echo ""

# Summary
echo "=========================================="
echo "✅ IAM Setup Complete!"
echo "=========================================="
echo ""
echo "Created Resources:"
echo "  - Policy: ${POLICY_NAME}"
echo "  - Role: ${ROLE_NAME}"
echo "  - Instance Profile: ${INSTANCE_PROFILE_NAME}"
echo ""
echo "Next Steps:"
echo "1. Attach this instance profile to your EC2 instance:"
echo ""
echo "   # Using AWS Console:"
echo "   - Go to EC2 Console → Select your instance"
echo "   - Actions → Security → Modify IAM Role"
echo "   - Select: ${INSTANCE_PROFILE_NAME}"
echo "   - Click Update IAM Role"
echo ""
echo "   # OR using AWS CLI:"
read -p "   Enter your EC2 Instance ID (e.g., i-0123456789abcdef0): " INSTANCE_ID
echo ""
if [ ! -z "$INSTANCE_ID" ]; then
    echo "   Attaching instance profile to ${INSTANCE_ID}..."
    
    # Check if instance already has a profile
    EXISTING_PROFILE=$(aws ec2 describe-iam-instance-profile-associations \
      --filters "Name=instance-id,Values=${INSTANCE_ID}" \
      --query 'IamInstanceProfileAssociations[0].AssociationId' \
      --output text 2>/dev/null)
    
    if [ "$EXISTING_PROFILE" != "None" ] && [ ! -z "$EXISTING_PROFILE" ]; then
        echo "   Replacing existing instance profile..."
        aws ec2 replace-iam-instance-profile-association \
          --association-id "${EXISTING_PROFILE}" \
          --iam-instance-profile "Name=${INSTANCE_PROFILE_NAME}"
        echo "   ✓ Instance profile replaced"
    else
        echo "   Attaching new instance profile..."
        aws ec2 associate-iam-instance-profile \
          --instance-id "${INSTANCE_ID}" \
          --iam-instance-profile "Name=${INSTANCE_PROFILE_NAME}"
        echo "   ✓ Instance profile attached"
    fi
    echo ""
    echo "2. Verify the setup:"
    echo "   ssh to your instance and run:"
    echo "   aws s3 ls s3://${BUCKET_NAME}/AWSLogs/ --region me-south-1"
else
    echo "   Skipped instance attachment. You can do this manually."
fi
echo ""
echo "3. Restart the CloudTrail processor:"
echo "   sudo systemctl restart cloudtrail-processor"
echo ""

# Cleanup
rm -f /tmp/cloudtrail-processor-policy.json /tmp/ec2-trust-policy.json

echo "🎉 Done! Your EC2 instance now has minimal permissions to read CloudTrail logs."
