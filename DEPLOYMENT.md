# Full Deployment Guide - CloudTrail → Promtail → Grafana

Complete step-by-step instructions to deploy all files to the correct locations on EC2 after copying the code.

---

## Quick Start (Fresh Install)

```bash
cd ~/cloudtrail-promtail-grafana-1
chmod +x setup.sh
./setup.sh
```

The script will prompt for AWS region, S3 bucket, and Loki IP. Skip to **Step 11** for Grafana dashboard import.

---

## Manual Deployment (or Update Existing)

---

## Overview

| Component | Location on EC2 | Purpose |
|-----------|-----------------|---------|
| CloudTrail Processor | `/opt/cloudtrail-processor/` | Python app that reads CloudTrail from S3, writes logs |
| Promtail Config | `/etc/promtail/` | Config for Promtail to read logs and push to Loki |
| Systemd Services | `/etc/systemd/system/` | Service definitions for processor and Promtail |
| Processed Logs | `/var/log/cloudtrail-processed/` | Output directory (Promtail tails these) |
| State File | `/var/lib/promtail/` | Processor state + Promtail positions |

---

## Prerequisites

- EC2 instance with IAM role (or AWS credentials) that can read CloudTrail S3 bucket
- Python 3, AWS CLI installed
- Second EC2 with Loki running (for Promtail to push logs)

---

## Step 1: Copy Code to EC2

```bash
# Option A: SCP from your local machine
scp -r cloudtrail-promtail-grafana-1 ubuntu@<EC2-IP>:~/

# Option B: Git clone on EC2
ssh ubuntu@<EC2-IP>
git clone <your-repo-url> cloudtrail-promtail-grafana-1
cd cloudtrail-promtail-grafana-1
```

---

## Step 2: Create Directories

```bash
sudo mkdir -p /opt/cloudtrail-processor
sudo mkdir -p /var/log/cloudtrail-processed
sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail

# Set ownership (use ec2-user for Amazon Linux, ubuntu for Ubuntu)
sudo chown -R ubuntu:ubuntu /opt/cloudtrail-processor
sudo chown -R ubuntu:ubuntu /var/log/cloudtrail-processed
sudo chown -R ubuntu:ubuntu /var/lib/promtail
sudo chown -R ubuntu:ubuntu /etc/promtail
```

---

## Step 3: Copy CloudTrail Processor Files

```bash
cd ~/cloudtrail-promtail-grafana-1

# Copy processor code and config
sudo cp cloudtrail_processor.py /opt/cloudtrail-processor/
sudo cp config.yaml /opt/cloudtrail-processor/
sudo cp requirements.txt /opt/cloudtrail-processor/
sudo chown ubuntu:ubuntu /opt/cloudtrail-processor/*
```

---

## Step 4: Copy Promtail Config

```bash
sudo cp promtail-config.yaml /etc/promtail/promtail-config.yaml
sudo chown ubuntu:ubuntu /etc/promtail/promtail-config.yaml
```

**Important:** Edit `promtail-config.yaml` and update the Loki URL if needed:

```bash
sudo nano /etc/promtail/promtail-config.yaml
# clients:
#   - url: http://16.24.169.121:3100/loki/api/v1/push   # Use your Loki EC2 IP
```

---

## Step 5: Update config.yaml for Your Environment

```bash
sudo nano /opt/cloudtrail-processor/config.yaml
```

Update these values:

```yaml
aws:
  region: me-south-1              # Your AWS region
  s3_bucket: your-cloudtrail-bucket-name
  s3_prefix: AWSLogs/

output_dir: /var/log/cloudtrail-processed
state_file: /var/lib/promtail/cloudtrail-state.json
retention_days: 7
```

---

## Step 6: Install Python Dependencies

```bash
cd /opt/cloudtrail-processor
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt
```

---

## Step 7: Install Systemd Service Files

```bash
cd ~/cloudtrail-promtail-grafana-1

# For Ubuntu
sudo cp cloudtrail-processor.service /etc/systemd/system/
sudo cp promtail.service /etc/systemd/system/

# For Amazon Linux (ec2-user instead of ubuntu)
sudo sed 's/User=ubuntu/User=ec2-user/' cloudtrail-processor.service | \
  sudo sed 's/Group=ubuntu/Group=ec2-user/' | \
  sudo tee /etc/systemd/system/cloudtrail-processor.service

sudo sed 's/User=ubuntu/User=ec2-user/' promtail.service | \
  sudo sed 's/Group=ubuntu/Group=ec2-user/' | \
  sudo tee /etc/systemd/system/promtail.service
```

---

## Step 8: Verify Promtail is Installed

```bash
which promtail
# If not found, install it:
cd /tmp
curl -O -L "https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip"
unzip -q promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail
```

---

## Step 9: Enable and Start Services

```bash
sudo systemctl daemon-reload
sudo systemctl enable cloudtrail-processor
sudo systemctl enable promtail
sudo systemctl start cloudtrail-processor
sudo systemctl start promtail
```

---

## Step 10: Verify Everything Works

```bash
# Check processor status
sudo systemctl status cloudtrail-processor

# Check Promtail status
sudo systemctl status promtail

# Check processed logs are being created
ls -lh /var/log/cloudtrail-processed/

# Watch processor logs
sudo journalctl -u cloudtrail-processor -f
```

---

## Step 11: Import Grafana Dashboard (on Grafana/Loki EC2 or separate Grafana instance)

1. Open Grafana (e.g. http://16.24.169.121:3000)
2. Go to **Dashboards** → **Import**
3. Upload `grafana-cloudtrail-dashboard.json` or paste its contents
4. Select Loki as datasource
5. Click **Import**

---

## Quick Update (When Code Changes)

If you've already deployed and only need to update files after code changes:

```bash
cd ~/cloudtrail-promtail-grafana-1

# 1. Update processor
sudo cp cloudtrail_processor.py /opt/cloudtrail-processor/
sudo systemctl restart cloudtrail-processor

# 2. Update Promtail config
sudo cp promtail-config.yaml /etc/promtail/promtail-config.yaml
sudo systemctl restart promtail

# 3. Re-import dashboard in Grafana (if dashboard changed)
```

---

## File Reference

| Source File | Destination |
|-------------|-------------|
| `cloudtrail_processor.py` | `/opt/cloudtrail-processor/cloudtrail_processor.py` |
| `config.yaml` | `/opt/cloudtrail-processor/config.yaml` |
| `requirements.txt` | `/opt/cloudtrail-processor/requirements.txt` |
| `promtail-config.yaml` | `/etc/promtail/promtail-config.yaml` |
| `cloudtrail-processor.service` | `/etc/systemd/system/cloudtrail-processor.service` |
| `promtail.service` | `/etc/systemd/system/promtail.service` |
| `grafana-cloudtrail-dashboard.json` | Import via Grafana UI |

---

---

## Main Dashboard (EC2 & Application Status)

The `grafana-main-dashboard.json` provides a single dashboard for:
- **EC2 Status** – Which instances are UP (sending logs) vs DOWN
- **All Errors** – Aggregated errors from every EC2 and application
- **Errors by Instance/Application** – Identify problematic servers

### Setup Requirements

1. **CloudTrail EC2** – Uses `promtail-config.yaml` with `instance: cloudtrail-processor` (already added).
2. **Other EC2s** – Deploy `promtail-ec2-config.yaml` on each EC2 to send syslog/app logs.

### Deploy Promtail on Each EC2 (for syslog/app logs)

```bash
# On each EC2 (except the CloudTrail processor which already has Promtail)
cd ~/cloudtrail-promtail-grafana-1
sed "s/INSTANCE_ID/$(hostname)/" promtail-ec2-config.yaml > /tmp/promtail-ec2.yaml
# Edit /tmp/promtail-ec2.yaml - set Loki URL, remove job configs for log paths that don't exist
sudo cp /tmp/promtail-ec2.yaml /etc/promtail/promtail-config.yaml
# Run Promtail: /usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml
```

### Update CloudTrail Instance Label

In `promtail-config.yaml` on the CloudTrail EC2, change `instance: cloudtrail-processor` to your hostname if desired:

```yaml
labels:
  instance: ip-172-31-10-39   # Or: $(hostname)
```

### Import Main Dashboard

1. Grafana → **Dashboards** → **Import**
2. Upload `grafana-main-dashboard.json`
3. Select Loki datasource
4. Import

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No logs in `/var/log/cloudtrail-processed/` | Check AWS credentials, S3 bucket, IAM permissions. `journalctl -u cloudtrail-processor -f` |
| Promtail not sending to Loki | Check Loki URL in promtail-config.yaml, ensure Loki is running and reachable |
| No iam_username in dashboard | Ensure updated `cloudtrail_processor.py` is deployed and restarted. Old logs won't have it. |
| Permission denied | `sudo chown -R ubuntu:ubuntu /opt/cloudtrail-processor /var/log/cloudtrail-processed` |
