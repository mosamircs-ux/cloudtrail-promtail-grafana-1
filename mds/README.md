# CloudTrail to Grafana via Promtail Setup

## Architecture Overview

```
CloudTrail → S3 Bucket → Python Script → Local Files → Promtail → Loki → Grafana
```

## Components

### EC2 #1 (CloudTrail Processor + Promtail)
- Python script to download CloudTrail logs from S3
- Parse and format logs
- Promtail to ship logs to Loki
- Systemd service for automation

### EC2 #2 (Monitoring - Existing)
- Loki (receives logs)
- Grafana (visualization)

## Setup Steps

### 1. EC2 #1 Setup (CloudTrail Processor)

#### Prerequisites
- Ubuntu/Amazon Linux EC2 instance
- IAM Role with S3 read access to CloudTrail bucket
- Network access to EC2 #2 (Loki port 3100)

#### Installation Commands
```bash
# Update system
sudo apt update && sudo apt upgrade -y  # Ubuntu
# OR
sudo yum update -y  # Amazon Linux

# Install Python and dependencies
sudo apt install -y python3 python3-pip unzip  # Ubuntu
# OR
sudo yum install -y python3 python3-pip unzip  # Amazon Linux

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Promtail
cd /tmp
curl -O -L "https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip"
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail

# Create directories
sudo mkdir -p /opt/cloudtrail-processor
sudo mkdir -p /var/log/cloudtrail-processed
sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail

# Set permissions
sudo chown -R ubuntu:ubuntu /opt/cloudtrail-processor  # Ubuntu
sudo chown -R ec2-user:ec2-user /var/log/cloudtrail-processed
sudo chown -R ubuntu:ubuntu /var/lib/promtail
```

### 2. Configuration Files

See individual files in this directory:
- `cloudtrail_processor.py` - Main Python script
- `config.yaml` - Configuration
- `promtail-config.yaml` - Promtail configuration
- `cloudtrail-processor.service` - Systemd service
- `promtail.service` - Promtail systemd service
- `requirements.txt` - Python dependencies

### 3. Installation

```bash
# Copy files to EC2 #1
cd /opt/cloudtrail-processor
sudo pip3 install -r requirements.txt

# Edit config.yaml with your settings
sudo nano config.yaml

# Edit promtail config
sudo nano /etc/promtail/promtail-config.yaml

# Install systemd services
sudo cp cloudtrail-processor.service /etc/systemd/system/
sudo cp promtail.service /etc/systemd/system/

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable cloudtrail-processor
sudo systemctl enable promtail
sudo systemctl start cloudtrail-processor
sudo systemctl start promtail

# Check status
sudo systemctl status cloudtrail-processor
sudo systemctl status promtail
```

### 4. EC2 #2 Setup (Loki Configuration)

Update Loki configuration to accept remote connections:

```yaml
# /etc/loki/loki-config.yaml
server:
  http_listen_address: 0.0.0.0  # Listen on all interfaces
  http_listen_port: 3100
```

Restart Loki:
```bash
sudo systemctl restart loki
```

### 5. Security Groups

#### EC2 #1 (Outbound)
- Allow HTTPS (443) to S3
- Allow TCP 3100 to EC2 #2 (Loki)

#### EC2 #2 (Inbound)
- Allow TCP 3100 from EC2 #1

## Monitoring

### Check Logs
```bash
# CloudTrail Processor logs
sudo journalctl -u cloudtrail-processor -f

# Promtail logs
sudo journalctl -u promtail -f

# Processed CloudTrail logs
ls -lh /var/log/cloudtrail-processed/
```

### Verify in Grafana

1. Go to Grafana → Explore
2. Select Loki data source
3. Query: `{job="cloudtrail"}`
4. You should see CloudTrail events

## Grafana Dashboard

Import the provided dashboard JSON:
- `grafana-cloudtrail-dashboard.json`

## Troubleshooting

### No logs appearing in Grafana
```bash
# Check if files are being created
ls -lh /var/log/cloudtrail-processed/

# Check Promtail is reading files
sudo journalctl -u promtail -n 100

# Test Loki connectivity from EC2 #1
curl http://<EC2-2-IP>:3100/ready
```

### Python script errors
```bash
# Check service status
sudo systemctl status cloudtrail-processor

# View detailed logs
sudo journalctl -u cloudtrail-processor -n 100 --no-pager
```

### S3 Access Issues
```bash
# Verify IAM role
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://YOUR-CLOUDTRAIL-BUCKET/
```

## Cost Optimization

- Use t3.micro or t3.small for EC2 #1
- Set retention policy in config.yaml to delete old processed logs
- Use S3 lifecycle policies to archive old CloudTrail logs

## Security Best Practices

- Use IAM roles instead of access keys
- Restrict Security Groups to minimum required
- Enable CloudTrail log file validation
- Use VPC endpoints for S3 access (no internet charges)
- Encrypt logs at rest and in transit
