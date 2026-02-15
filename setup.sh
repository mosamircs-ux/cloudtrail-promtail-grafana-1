#!/bin/bash

# CloudTrail Promtail Server - Complete Setup Script
# Run this on EC2 #1 (CloudTrail Processor)

set -e

echo "=========================================="
echo "CloudTrail Promtail Server Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run as root. Run as ubuntu/ec2-user${NC}"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}Cannot detect OS${NC}"
    exit 1
fi

echo -e "${GREEN}Detected OS: $OS${NC}"
echo ""

# Update system
echo -e "${YELLOW}[1/10] Updating system...${NC}"
if [ "$OS" = "ubuntu" ]; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y python3 python3-pip python3-venv unzip curl wget
elif [ "$OS" = "amzn" ] || [ "$OS" = "rhel" ]; then
    sudo yum update -y
    sudo yum install -y python3 python3-pip unzip curl wget
fi

# Install AWS CLI
echo -e "${YELLOW}[2/10] Installing AWS CLI...${NC}"
if ! command -v aws &> /dev/null; then
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    echo -e "${GREEN}AWS CLI installed${NC}"
else
    echo -e "${GREEN}AWS CLI already installed${NC}"
fi

# Verify AWS credentials
echo -e "${YELLOW}[3/10] Verifying AWS credentials...${NC}"
if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}AWS credentials configured${NC}"
    aws sts get-caller-identity
else
    echo -e "${RED}AWS credentials not configured!${NC}"
    echo "Please configure IAM role or run: aws configure"
    exit 1
fi

# Install Promtail
echo -e "${YELLOW}[4/10] Installing Promtail...${NC}"
if ! command -v promtail &> /dev/null; then
    cd /tmp
    PROMTAIL_VERSION="2.9.3"
    curl -O -L "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
    unzip -q promtail-linux-amd64.zip
    sudo mv promtail-linux-amd64 /usr/local/bin/promtail
    sudo chmod +x /usr/local/bin/promtail
    rm promtail-linux-amd64.zip
    echo -e "${GREEN}Promtail installed${NC}"
else
    echo -e "${GREEN}Promtail already installed${NC}"
fi

# Create directories
echo -e "${YELLOW}[5/10] Creating directories...${NC}"
sudo mkdir -p /opt/cloudtrail-processor
sudo mkdir -p /var/log/cloudtrail-processed
sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail

# Set permissions
if [ "$OS" = "ubuntu" ]; then
    USER_NAME="ubuntu"
elif [ "$OS" = "amzn" ] || [ "$OS" = "rhel" ]; then
    USER_NAME="ec2-user"
fi

sudo chown -R $USER_NAME:$USER_NAME /opt/cloudtrail-processor
sudo chown -R $USER_NAME:$USER_NAME /var/log/cloudtrail-processed
sudo chown -R $USER_NAME:$USER_NAME /var/lib/promtail
sudo chown -R $USER_NAME:$USER_NAME /etc/promtail

echo -e "${GREEN}Directories created${NC}"

# Copy files (assuming they're in current directory)
echo -e "${YELLOW}[6/10] Copying configuration files...${NC}"
if [ -f "cloudtrail_processor.py" ]; then
    cp cloudtrail_processor.py /opt/cloudtrail-processor/
    cp config.yaml /opt/cloudtrail-processor/
    cp requirements.txt /opt/cloudtrail-processor/
    cp promtail-config.yaml /etc/promtail/
    echo -e "${GREEN}Files copied${NC}"
else
    echo -e "${RED}Configuration files not found in current directory!${NC}"
    echo "Please ensure all files are in the same directory as this script"
    exit 1
fi

# Install Python dependencies
echo -e "${YELLOW}[7/10] Installing Python dependencies...${NC}"
cd /opt/cloudtrail-processor

# Create virtual environment
echo "Creating Python virtual environment..."
python3 -m venv venv

# Install dependencies in virtual environment
echo "Installing dependencies in virtual environment..."
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt

echo -e "${GREEN}Python dependencies installed${NC}"

# Configure settings
echo -e "${YELLOW}[8/10] Configuration required...${NC}"
echo ""
echo -e "${YELLOW}Please provide the following information:${NC}"
echo ""

read -p "AWS Region (e.g., us-east-1): " AWS_REGION
read -p "S3 Bucket Name (CloudTrail logs): " S3_BUCKET
read -p "S3 Prefix (default: AWSLogs/): " S3_PREFIX
S3_PREFIX=${S3_PREFIX:-AWSLogs/}
read -p "Loki EC2 IP Address: " LOKI_IP

# Update config.yaml
sed -i "s/region: .*/region: $AWS_REGION/" /opt/cloudtrail-processor/config.yaml
sed -i "s/s3_bucket: .*/s3_bucket: $S3_BUCKET/" /opt/cloudtrail-processor/config.yaml
sed -i "s|s3_prefix: .*|s3_prefix: $S3_PREFIX|" /opt/cloudtrail-processor/config.yaml
sed -i "s|url: .*|url: http://$LOKI_IP:3100|" /opt/cloudtrail-processor/config.yaml

# Update promtail-config.yaml
sed -i "s|url: .*|url: http://$LOKI_IP:3100/loki/api/v1/push|" /etc/promtail/promtail-config.yaml

echo -e "${GREEN}Configuration updated${NC}"

# Install systemd services
echo -e "${YELLOW}[9/10] Installing systemd services...${NC}"

# Update service files with correct user
sed "s/User=ubuntu/User=$USER_NAME/" cloudtrail-processor.service | \
sed "s/Group=ubuntu/Group=$USER_NAME/" | \
sudo tee /etc/systemd/system/cloudtrail-processor.service > /dev/null

sed "s/User=ubuntu/User=$USER_NAME/" promtail.service | \
sed "s/Group=ubuntu/Group=$USER_NAME/" | \
sudo tee /etc/systemd/system/promtail.service > /dev/null

sudo systemctl daemon-reload
echo -e "${GREEN}Systemd services installed${NC}"

# Enable and start services
echo -e "${YELLOW}[10/10] Starting services...${NC}"
sudo systemctl enable cloudtrail-processor
sudo systemctl enable promtail
sudo systemctl start cloudtrail-processor
sudo systemctl start promtail

sleep 3

# Check status
echo ""
echo -e "${YELLOW}Service Status:${NC}"
echo ""
echo "CloudTrail Processor:"
sudo systemctl status cloudtrail-processor --no-pager -l | head -20
echo ""
echo "Promtail:"
sudo systemctl status promtail --no-pager -l | head -20

echo ""
echo -e "${GREEN}=========================================="
echo "Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Check logs: sudo journalctl -u cloudtrail-processor -f"
echo "2. Check Promtail: sudo journalctl -u promtail -f"
echo "3. Verify files: ls -lh /var/log/cloudtrail-processed/"
echo "4. Test Loki connection: curl http://$LOKI_IP:3100/ready"
echo ""
echo "Grafana queries:"
echo '  {job="cloudtrail"}'
echo '  {job="cloudtrail", access_key_id="AKIA..."}'
echo '  {job="cloudtrail", event_name="ConsoleLogin"}'
echo ""
