# Quick Start Guide - CloudTrail to Grafana

## Overview

This setup allows you to monitor all AWS CloudTrail events in Grafana, tracking:
- **Who**: Which user/access key performed actions
- **What**: What resources were accessed
- **When**: Timestamp of each event
- **Where**: AWS region and source IP
- **Result**: Success or failure

---

## Architecture

```
┌──────────────┐
│  CloudTrail  │
│  (AWS)       │
└──────┬───────┘
       │ Writes logs
       ↓
┌──────────────┐
│  S3 Bucket   │
└──────┬───────┘
       │
       │ Downloads & Parses
       ↓
┌─────────────────────────────┐
│  EC2 #1 (Processor)         │
│  • Python Script            │
│  • Promtail                 │
└──────────┬──────────────────┘
           │ Pushes logs
           ↓
┌─────────────────────────────┐
│  EC2 #2 (Monitoring)        │
│  • Loki                     │
│  • Grafana                  │
└─────────────────────────────┘
```

---

## Prerequisites

### EC2 #1 (CloudTrail Processor)
- **Instance Type**: t3.small or larger
- **OS**: Ubuntu 20.04+ or Amazon Linux 2
- **IAM Role**: S3 read access to CloudTrail bucket
- **Security Group**: Outbound to S3 (443) and Loki (3100)

### EC2 #2 (Monitoring - Existing)
- **Grafana**: Running and accessible
- **Loki**: Running on port 3100
- **Security Group**: Inbound from EC2 #1 on port 3100

### AWS Resources
- **CloudTrail**: Enabled and logging to S3
- **S3 Bucket**: Contains CloudTrail logs

---

## Installation Steps

### Step 1: Prepare EC2 #1

```bash
# SSH into EC2 #1
ssh -i your-key.pem ubuntu@ec2-ip-address

# Create working directory
mkdir -p ~/cloudtrail-setup
cd ~/cloudtrail-setup
```

### Step 2: Upload Files to EC2 #1

Upload all files from this directory to EC2 #1:

```bash
# From your local machine
scp -i your-key.pem -r cloudtrail-promtail-setup/* ubuntu@ec2-ip:~/cloudtrail-setup/
```

Or download from GitHub/S3 if you've stored them there.

### Step 3: Run Setup Script

```bash
# Make setup script executable
chmod +x setup.sh

# Run setup (will ask for configuration)
./setup.sh
```

The script will ask for:
- AWS Region (e.g., `us-east-1`)
- S3 Bucket Name (e.g., `my-cloudtrail-bucket`)
- S3 Prefix (default: `AWSLogs/`)
- Loki EC2 IP Address (e.g., `10.0.1.50`)

### Step 4: Verify Installation

```bash
# Check CloudTrail processor status
sudo systemctl status cloudtrail-processor

# Check Promtail status
sudo systemctl status promtail

# View logs
sudo journalctl -u cloudtrail-processor -f

# Check if files are being created
ls -lh /var/log/cloudtrail-processed/
```

### Step 5: Configure Loki on EC2 #2

SSH into EC2 #2 and update Loki config:

```bash
# Edit Loki config
sudo nano /etc/loki/loki-config.yaml

# Ensure it has:
server:
  http_listen_address: 0.0.0.0  # Listen on all interfaces
  http_listen_port: 3100

# Restart Loki
sudo systemctl restart loki

# Verify Loki is accessible
curl http://localhost:3100/ready
```

### Step 6: Test Connection from EC2 #1

```bash
# From EC2 #1, test Loki connection
curl http://LOKI-EC2-IP:3100/ready

# Should return: ready
```

### Step 7: Import Grafana Dashboard

1. Open Grafana in browser
2. Go to **Dashboards** → **Import**
3. Click **Upload JSON file**
4. Select `grafana-cloudtrail-dashboard.json`
5. Select your Loki data source
6. Click **Import**

---

## Verification

### Check Logs in Grafana

1. Go to **Explore** in Grafana
2. Select **Loki** data source
3. Run query: `{job="cloudtrail"}`
4. You should see CloudTrail events

### Example Queries

```logql
# All CloudTrail events
{job="cloudtrail"}

# Events by specific access key
{job="cloudtrail", access_key_id="AKIA..."}

# Failed events only
{job="cloudtrail", success="false"}

# Console login events
{job="cloudtrail", event_name="ConsoleLogin"}

# Events in specific region
{job="cloudtrail", aws_region="us-east-1"}

# Count events per access key
sum by (access_key_id) (count_over_time({job="cloudtrail"}[1h]))
```

---

## Monitoring

### View Service Logs

```bash
# CloudTrail processor
sudo journalctl -u cloudtrail-processor -f

# Promtail
sudo journalctl -u promtail -f
```

### Check Processed Files

```bash
# List processed log files
ls -lh /var/log/cloudtrail-processed/

# View a processed file
cat /var/log/cloudtrail-processed/cloudtrail_*.log | head -5
```

### Monitor Resource Usage

```bash
# CPU and memory
htop

# Disk usage
df -h
du -sh /var/log/cloudtrail-processed/
```

---

## Troubleshooting

### No Logs Appearing

1. **Check CloudTrail processor**:
   ```bash
   sudo systemctl status cloudtrail-processor
   sudo journalctl -u cloudtrail-processor -n 50
   ```

2. **Check S3 access**:
   ```bash
   aws s3 ls s3://your-bucket-name/
   ```

3. **Check Promtail**:
   ```bash
   sudo systemctl status promtail
   sudo journalctl -u promtail -n 50
   ```

4. **Check Loki connectivity**:
   ```bash
   curl https://16.24.169.121:3100/ready
   ```

### High CPU/Memory Usage

- Reduce processing frequency in `config.yaml`:
  ```yaml
  interval_seconds: 600  # Check every 10 minutes instead of 5
  ```

- Reduce retention:
  ```yaml
  retention_days: 3  # Keep logs for 3 days instead of 7
  ```

### S3 Access Denied

- Check IAM role permissions (see `IAM-POLICY.md`)
- Verify role is attached to EC2 #1:
  ```bash
  curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
  ```

---

## Maintenance

### Update Configuration

```bash
# Edit config
sudo nano /opt/cloudtrail-processor/config.yaml

# Restart service
sudo systemctl restart cloudtrail-processor
```

### Clean Old Logs Manually

```bash
# Remove logs older than 7 days
find /var/log/cloudtrail-processed/ -name "*.log" -mtime +7 -delete
```

### Update Python Script

```bash
cd /opt/cloudtrail-processor
sudo nano cloudtrail_processor.py
sudo systemctl restart cloudtrail-processor
```

---

## Security Recommendations

1. ✅ Use IAM roles (not access keys)
2. ✅ Restrict Security Groups to minimum required
3. ✅ Enable CloudTrail log file validation
4. ✅ Use VPC endpoints for S3 (no internet charges)
5. ✅ Encrypt logs at rest
6. ✅ Set up alerts for suspicious activities
7. ✅ Regularly review access patterns

---

## Next Steps

1. **Set up alerts** in Grafana for:
   - Failed login attempts
   - Unauthorized access attempts
   - Unusual access patterns
   - Root account usage

2. **Create custom dashboards** for:
   - Specific users/teams
   - Specific AWS services
   - Compliance reporting

3. **Optimize performance**:
   - Adjust processing interval
   - Set up log rotation
   - Monitor resource usage

---

## Support

For issues or questions:
1. Check logs: `sudo journalctl -u cloudtrail-processor -f`
2. Review configuration: `cat /opt/cloudtrail-processor/config.yaml`
3. Test connectivity: `curl http://LOKI-IP:3100/ready`
4. Verify IAM permissions: See `IAM-POLICY.md`

---

## Cost Optimization

- Use **t3.micro** for EC2 #1 (sufficient for most workloads)
- Set up **S3 lifecycle policies** to archive old CloudTrail logs
- Use **VPC endpoints** for S3 to avoid data transfer charges
- Adjust **processing interval** based on your needs
- Set **retention policies** to delete old processed logs
