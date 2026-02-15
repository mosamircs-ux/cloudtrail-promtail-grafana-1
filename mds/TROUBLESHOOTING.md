# Troubleshooting Guide

## Common Issues and Solutions

---

## Issue 1: Python externally-managed-environment Error

### Error Message:
```
error: externally-managed-environment
× This environment is externally managed
```

### Solution:
The setup script has been updated to use Python virtual environment. If you encounter this error:

**Option 1: Use Updated setup.sh (Recommended)**
```bash
# The new setup.sh automatically creates a virtual environment
./setup.sh
```

**Option 2: Manual Virtual Environment Setup**
```bash
# Create virtual environment
cd /opt/cloudtrail-processor
python3 -m venv venv

# Install dependencies
./venv/bin/pip install -r requirements.txt

# Update systemd service to use venv Python
sudo nano /etc/systemd/system/cloudtrail-processor.service
# Change ExecStart to:
# ExecStart=/opt/cloudtrail-processor/venv/bin/python /opt/cloudtrail-processor/cloudtrail_processor.py

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart cloudtrail-processor
```

**Option 3: Override (Not Recommended)**
```bash
# Only if you understand the risks
sudo pip3 install -r requirements.txt --break-system-packages
```

---

## Issue 2: HTTPS Connection to Loki Fails

### Error Message:
```
SSL: CERTIFICATE_VERIFY_FAILED
```

### Cause:
You configured Loki URL as `https://` but Loki might not have SSL certificate.

### Solution:

**Option 1: Use HTTP Instead (if Loki doesn't have SSL)**
```bash
# Edit promtail config
sudo nano /etc/promtail/promtail-config.yaml

# Change:
# url: https://16.24.169.121:3100/loki/api/v1/push
# To:
# url: http://16.24.169.121:3100/loki/api/v1/push

# Restart Promtail
sudo systemctl restart promtail
```

**Option 2: Configure Loki with SSL Certificate**
```bash
# On EC2 #2 (Loki server)
# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/loki/loki.key \
  -out /etc/loki/loki.crt

# Update Loki config
sudo nano /etc/loki/loki-config.yaml

# Add:
server:
  http_listen_address: 0.0.0.0
  http_listen_port: 3100
  http_tls_config:
    cert_file: /etc/loki/loki.crt
    key_file: /etc/loki/loki.key

# Restart Loki
sudo systemctl restart loki
```

**Option 3: Disable SSL Verification (Not Recommended for Production)**
```yaml
# In promtail-config.yaml
clients:
  - url: https://16.24.169.121:3100/loki/api/v1/push
    tls_config:
      insecure_skip_verify: true
```

---

## Issue 3: Cannot Connect to Loki

### Error Message:
```
connection refused
connection timeout
```

### Diagnosis:
```bash
# From EC2 #1, test connection
curl http://16.24.169.121:3100/ready
curl https://16.24.169.121:3100/ready

# Check if port is open
telnet 16.24.169.121 3100
nc -zv 16.24.169.121 3100
```

### Solutions:

**Check 1: Loki is Running**
```bash
# On EC2 #2
sudo systemctl status loki
sudo journalctl -u loki -n 50
```

**Check 2: Loki Listening on Correct Interface**
```bash
# On EC2 #2
sudo netstat -tlnp | grep 3100

# Should show: 0.0.0.0:3100 (not 127.0.0.1:3100)
```

If showing `127.0.0.1:3100`, update Loki config:
```yaml
# /etc/loki/loki-config.yaml
server:
  http_listen_address: 0.0.0.0  # Not 127.0.0.1
  http_listen_port: 3100
```

**Check 3: Security Groups**
```bash
# Verify EC2 #2 security group allows inbound on 3100 from EC2 #1
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

Add rule if missing:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 3100 \
  --source-group sg-yyyyy  # EC2 #1 security group
```

**Check 4: Network ACLs**
```bash
# Check if Network ACLs are blocking
aws ec2 describe-network-acls --filters "Name=vpc-id,Values=vpc-xxxxx"
```

---

## Issue 4: No Logs Appearing in Grafana

### Diagnosis Steps:

**Step 1: Check if CloudTrail Processor is Running**
```bash
sudo systemctl status cloudtrail-processor
sudo journalctl -u cloudtrail-processor -n 50
```

**Step 2: Check if Files are Being Created**
```bash
ls -lh /var/log/cloudtrail-processed/
tail -f /var/log/cloudtrail-processed/cloudtrail_*.log
```

**Step 3: Check Promtail is Running**
```bash
sudo systemctl status promtail
sudo journalctl -u promtail -n 50
```

**Step 4: Check Promtail is Reading Files**
```bash
# Check positions file
cat /var/lib/promtail/positions.yaml
```

**Step 5: Test Loki Query**
```bash
# From EC2 #1
curl -G -s "http://16.24.169.121:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="cloudtrail"}' | jq
```

### Common Causes:

**Cause 1: S3 Access Denied**
```bash
# Check IAM role
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://your-cloudtrail-bucket/
```

**Cause 2: No New CloudTrail Logs**
```bash
# Check CloudTrail is enabled
aws cloudtrail describe-trails

# Check recent logs in S3
aws s3 ls s3://your-cloudtrail-bucket/AWSLogs/ --recursive | tail -20
```

**Cause 3: Wrong S3 Bucket/Prefix**
```bash
# Verify config
cat /opt/cloudtrail-processor/config.yaml
```

**Cause 4: Promtail Not Pushing**
```bash
# Check Promtail logs for errors
sudo journalctl -u promtail -n 100 | grep -i error
```

---

## Issue 5: High CPU/Memory Usage

### Diagnosis:
```bash
# Check resource usage
top
htop

# Check specific processes
ps aux | grep python
ps aux | grep promtail
```

### Solutions:

**Solution 1: Reduce Processing Frequency**
```bash
# Edit config
sudo nano /opt/cloudtrail-processor/config.yaml

# Change:
interval_seconds: 600  # 10 minutes instead of 5

# Restart
sudo systemctl restart cloudtrail-processor
```

**Solution 2: Reduce Log Retention**
```bash
# Edit config
sudo nano /opt/cloudtrail-processor/config.yaml

# Change:
retention_days: 3  # 3 days instead of 7

# Restart
sudo systemctl restart cloudtrail-processor
```

**Solution 3: Upgrade EC2 Instance**
```bash
# Stop services
sudo systemctl stop cloudtrail-processor
sudo systemctl stop promtail

# Resize EC2 instance type (via AWS Console or CLI)
# Then restart services
```

---

## Issue 6: Disk Space Full

### Diagnosis:
```bash
# Check disk usage
df -h

# Check log directory size
du -sh /var/log/cloudtrail-processed/
du -sh /opt/cloudtrail-processor/
```

### Solutions:

**Solution 1: Clean Old Logs**
```bash
# Manual cleanup
find /var/log/cloudtrail-processed/ -name "*.log" -mtime +7 -delete

# Check state file size
ls -lh /var/lib/promtail/cloudtrail-state.json
```

**Solution 2: Reduce Retention**
```bash
# Edit config
sudo nano /opt/cloudtrail-processor/config.yaml

# Change:
retention_days: 1  # Keep only 1 day

# Restart
sudo systemctl restart cloudtrail-processor
```

**Solution 3: Add EBS Volume**
```bash
# Create and attach EBS volume via AWS Console
# Then mount it
sudo mkfs -t ext4 /dev/xvdf
sudo mkdir /mnt/cloudtrail-logs
sudo mount /dev/xvdf /mnt/cloudtrail-logs

# Update config to use new location
sudo nano /opt/cloudtrail-processor/config.yaml
# Change output_dir to: /mnt/cloudtrail-logs

# Update promtail config
sudo nano /etc/promtail/promtail-config.yaml
# Change __path__ to: /mnt/cloudtrail-logs/*.log
```

---

## Issue 7: Service Won't Start

### Error: "Failed to start cloudtrail-processor.service"

**Check 1: View Error Details**
```bash
sudo systemctl status cloudtrail-processor -l
sudo journalctl -u cloudtrail-processor -n 50 --no-pager
```

**Check 2: Verify Files Exist**
```bash
ls -l /opt/cloudtrail-processor/cloudtrail_processor.py
ls -l /opt/cloudtrail-processor/venv/bin/python
ls -l /opt/cloudtrail-processor/config.yaml
```

**Check 3: Test Script Manually**
```bash
cd /opt/cloudtrail-processor
./venv/bin/python cloudtrail_processor.py
```

**Check 4: Verify Permissions**
```bash
ls -la /opt/cloudtrail-processor/
ls -la /var/log/cloudtrail-processed/
ls -la /var/lib/promtail/
```

**Fix Permissions:**
```bash
sudo chown -R ubuntu:ubuntu /opt/cloudtrail-processor
sudo chown -R ubuntu:ubuntu /var/log/cloudtrail-processed
sudo chown -R ubuntu:ubuntu /var/lib/promtail
```

---

## Issue 8: AWS Credentials Not Working

### Error: "Unable to locate credentials"

**Solution 1: Verify IAM Role**
```bash
# Check if role is attached
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Should return role name
```

**Solution 2: Attach IAM Role**
```bash
# Via AWS Console:
# EC2 → Instances → Select instance → Actions → Security → Modify IAM role

# Via CLI:
aws ec2 associate-iam-instance-profile \
  --instance-id i-xxxxx \
  --iam-instance-profile Name=CloudTrailProcessorRole
```

**Solution 3: Use AWS Configure (Not Recommended)**
```bash
# Only if IAM role is not an option
aws configure
# Enter access key and secret key
```

---

## Issue 9: Promtail Config File Not Found

### Error: "open /etc/promtail/promtail-config.yaml: no such file"

**Solution:**
```bash
# Check if file exists
ls -l /etc/promtail/

# If missing, copy from setup directory
cp ~/cloudtrail-setup/promtail-config.yaml /etc/promtail/

# Or download from your source
# Then restart
sudo systemctl restart promtail
```

---

## Issue 10: Grafana Shows "No Data"

### Diagnosis:

**Step 1: Verify Loki Data Source**
```
Grafana → Configuration → Data Sources → Loki
URL should be: http://localhost:3100 (if on same server)
```

**Step 2: Test Query in Explore**
```
Grafana → Explore → Select Loki
Query: {job="cloudtrail"}
```

**Step 3: Check Time Range**
```
Make sure time range includes when logs were sent
Try: Last 6 hours or Last 24 hours
```

**Step 4: Check Labels**
```
Query: {job="cloudtrail"}
If no results, try: {}
This shows all logs in Loki
```

---

## Useful Commands Reference

### Service Management
```bash
# Status
sudo systemctl status cloudtrail-processor
sudo systemctl status promtail

# Start/Stop/Restart
sudo systemctl start cloudtrail-processor
sudo systemctl stop cloudtrail-processor
sudo systemctl restart cloudtrail-processor

# Enable/Disable (auto-start on boot)
sudo systemctl enable cloudtrail-processor
sudo systemctl disable cloudtrail-processor

# View logs
sudo journalctl -u cloudtrail-processor -f
sudo journalctl -u promtail -f
```

### File Locations
```bash
# Configuration
/opt/cloudtrail-processor/config.yaml
/etc/promtail/promtail-config.yaml

# Scripts
/opt/cloudtrail-processor/cloudtrail_processor.py
/opt/cloudtrail-processor/venv/

# Logs
/var/log/cloudtrail-processed/
/var/lib/promtail/

# Services
/etc/systemd/system/cloudtrail-processor.service
/etc/systemd/system/promtail.service
```

### Testing
```bash
# Test S3 access
aws s3 ls s3://your-bucket/

# Test Loki connection
curl http://16.24.169.121:3100/ready

# Test Loki query
curl -G -s "http://16.24.169.121:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="cloudtrail"}' | jq

# Test Python script
cd /opt/cloudtrail-processor
./venv/bin/python cloudtrail_processor.py
```

---

## Getting Help

If you're still stuck:

1. **Check all logs**:
   ```bash
   sudo journalctl -u cloudtrail-processor -n 100 --no-pager
   sudo journalctl -u promtail -n 100 --no-pager
   ```

2. **Verify configuration**:
   ```bash
   cat /opt/cloudtrail-processor/config.yaml
   cat /etc/promtail/promtail-config.yaml
   ```

3. **Test each component separately**:
   - S3 access
   - Python script
   - Promtail
   - Loki connection
   - Grafana query

4. **Check AWS CloudTrail**:
   - Is CloudTrail enabled?
   - Are logs being written to S3?
   - Are logs recent?
