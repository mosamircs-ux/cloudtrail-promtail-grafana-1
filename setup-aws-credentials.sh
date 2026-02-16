#!/bin/bash
# Setup AWS credentials for CloudTrail processor
# Run on the EC2 where cloudtrail-processor runs

echo "=== CloudTrail Processor - AWS Credentials Setup ==="
echo ""

# Check which user the service runs as
SERVICE_USER=$(grep "^User=" /etc/systemd/system/cloudtrail-processor.service 2>/dev/null | cut -d= -f2)
SERVICE_USER=${SERVICE_USER:-ubuntu}

echo "CloudTrail processor runs as: $SERVICE_USER"
echo ""
echo "Choose authentication method:"
echo "  1. IAM Role (recommended, more secure)"
echo "  2. AWS CLI credentials (access key/secret)"
echo ""
read -p "Enter choice (1 or 2): " CHOICE

if [ "$CHOICE" = "1" ]; then
    echo ""
    echo "To use IAM Role:"
    echo "  1. Go to AWS Console → IAM → Roles → Create role"
    echo "  2. Trusted entity: AWS service → EC2"
    echo "  3. Add this inline policy:"
    echo ""
    cat << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": "arn:aws:s3:::YOUR-CLOUDTRAIL-BUCKET"
        },
        {
            "Effect": "Allow",
            "Action": ["s3:GetObject"],
            "Resource": "arn:aws:s3:::YOUR-CLOUDTRAIL-BUCKET/*"
        }
    ]
}
EOF
    echo ""
    echo "  4. Name the role (e.g. CloudTrailProcessorRole)"
    echo "  5. Go to EC2 Console → Instances → Select this instance"
    echo "  6. Actions → Security → Modify IAM role → Attach the role"
    echo "  7. Run: sudo systemctl restart cloudtrail-processor"
    echo ""
    echo "The role will be detected automatically - no credentials file needed."
    echo ""
    
elif [ "$CHOICE" = "2" ]; then
    echo ""
    echo "Configuring AWS CLI credentials for user: $SERVICE_USER"
    echo ""
    
    # Configure as the service user
    if [ "$SERVICE_USER" = "root" ]; then
        echo "Service runs as root."
        aws configure
    else
        echo "Running aws configure as $SERVICE_USER..."
        sudo -u $SERVICE_USER aws configure
    fi
    
    echo ""
    echo "Testing S3 access..."
    S3_BUCKET=$(grep "s3_bucket:" /opt/cloudtrail-processor/config.yaml 2>/dev/null | awk '{print $2}')
    if [ -n "$S3_BUCKET" ]; then
        if sudo -u $SERVICE_USER aws s3 ls "s3://$S3_BUCKET" --max-items 5 &>/dev/null; then
            echo "✓ Credentials work! Can access S3 bucket."
        else
            echo "✗ Can't access S3 bucket. Check:"
            echo "  - Credentials are correct"
            echo "  - Bucket name in config.yaml is correct"
            echo "  - IAM user has s3:ListBucket and s3:GetObject permissions"
        fi
    fi
    
    echo ""
    echo "Restarting cloudtrail-processor..."
    sudo systemctl restart cloudtrail-processor
    sleep 2
    
    if sudo systemctl is-active --quiet cloudtrail-processor; then
        echo "✓ Service is running"
        echo ""
        echo "Check logs in 30 seconds:"
        echo "  sudo journalctl -u cloudtrail-processor -n 50"
    else
        echo "✗ Service failed. Check logs:"
        sudo journalctl -u cloudtrail-processor -n 20 --no-pager
    fi
else
    echo "Invalid choice"
    exit 1
fi
