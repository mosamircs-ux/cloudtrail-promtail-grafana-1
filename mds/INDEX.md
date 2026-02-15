# CloudTrail to Grafana Monitoring - Complete Setup Package

## 📋 Project Overview

This package provides a complete solution for monitoring AWS CloudTrail logs in Grafana using Promtail and Loki. Track all AWS API calls, user activities, and access key usage in real-time.

---

## 🎯 What This Solves

- **Track Access Keys**: See which access key is used for what and when
- **Monitor User Activity**: Track all actions by users and roles
- **Security Monitoring**: Detect suspicious activities and unauthorized access
- **Compliance**: Audit trail for all AWS resource changes
- **Real-time Alerts**: Get notified of critical security events

---

## 📁 Package Contents

### 📘 Documentation Files

| File | Description |
|------|-------------|
| **README.md** | Main documentation with architecture overview and setup steps |
| **QUICKSTART.md** | Step-by-step quick start guide for rapid deployment |
| **IAM-POLICY.md** | IAM policies required for S3 access |
| **SECURITY-GROUPS.md** | Security group configuration for both EC2 instances |
| **ALERT-RULES.md** | Pre-configured alert rules for security monitoring |
| **QUERY-EXAMPLES.md** | 100+ Grafana query examples for CloudTrail analysis |

### 🔧 Configuration Files

| File | Description |
|------|-------------|
| **config.yaml** | Main configuration for CloudTrail processor |
| **promtail-config.yaml** | Promtail configuration for log shipping |
| **cloudtrail-processor.service** | Systemd service for CloudTrail processor |
| **promtail.service** | Systemd service for Promtail |
| **requirements.txt** | Python dependencies |

### 💻 Scripts

| File | Description |
|------|-------------|
| **cloudtrail_processor.py** | Python script to download and parse CloudTrail logs |
| **setup.sh** | Automated installation script for EC2 #1 |

### 📊 Grafana Resources

| File | Description |
|------|-------------|
| **grafana-cloudtrail-dashboard.json** | Pre-built Grafana dashboard |

---

## 🚀 Quick Start

### Prerequisites
- ✅ AWS CloudTrail enabled and logging to S3
- ✅ EC2 #1 for CloudTrail processing (t3.small recommended)
- ✅ EC2 #2 with Grafana + Loki already running
- ✅ IAM role with S3 read access for EC2 #1

### Installation (5 minutes)

1. **Upload files to EC2 #1**:
   ```bash
   scp -i your-key.pem -r cloudtrail-promtail-setup/* ubuntu@ec2-ip:~/
   ```

2. **Run setup script**:
   ```bash
   ssh -i your-key.pem ubuntu@ec2-ip
   cd ~/cloudtrail-promtail-setup
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Import Grafana dashboard**:
   - Open Grafana → Dashboards → Import
   - Upload `grafana-cloudtrail-dashboard.json`

4. **Done!** Check Grafana for CloudTrail events

---

## 📖 Detailed Documentation

### For First-Time Setup
1. Start with **QUICKSTART.md** for step-by-step instructions
2. Follow **IAM-POLICY.md** to configure permissions
3. Use **SECURITY-GROUPS.md** to set up networking

### For Configuration
1. Edit **config.yaml** for your AWS settings
2. Edit **promtail-config.yaml** for Loki endpoint
3. Customize **cloudtrail_processor.py** if needed

### For Monitoring
1. Import **grafana-cloudtrail-dashboard.json** to Grafana
2. Set up alerts from **ALERT-RULES.md**
3. Use **QUERY-EXAMPLES.md** for custom queries

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     AWS Cloud                            │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │  CloudTrail  │────────▶│  S3 Bucket   │             │
│  └──────────────┘         └──────┬───────┘             │
│                                   │                      │
└───────────────────────────────────┼──────────────────────┘
                                    │
                                    │ Downloads logs
                                    ▼
        ┌─────────────────────────────────────────┐
        │  EC2 #1 (CloudTrail Processor)          │
        │  ┌────────────────────────────────────┐ │
        │  │  cloudtrail_processor.py           │ │
        │  │  • Downloads from S3               │ │
        │  │  • Parses JSON logs                │ │
        │  │  • Extracts key information        │ │
        │  │  • Writes formatted logs           │ │
        │  └────────────────┬───────────────────┘ │
        │                   │                      │
        │  ┌────────────────▼───────────────────┐ │
        │  │  Promtail                          │ │
        │  │  • Reads formatted logs            │ │
        │  │  • Adds labels                     │ │
        │  │  • Ships to Loki                   │ │
        │  └────────────────┬───────────────────┘ │
        └───────────────────┼─────────────────────┘
                            │
                            │ Push logs
                            ▼
        ┌─────────────────────────────────────────┐
        │  EC2 #2 (Monitoring)                    │
        │  ┌────────────────────────────────────┐ │
        │  │  Loki                              │ │
        │  │  • Receives logs                   │ │
        │  │  • Indexes by labels               │ │
        │  │  • Stores time-series data         │ │
        │  └────────────────┬───────────────────┘ │
        │                   │                      │
        │  ┌────────────────▼───────────────────┐ │
        │  │  Grafana                           │ │
        │  │  • Visualizes logs                 │ │
        │  │  • Dashboards & alerts             │ │
        │  │  • User interface                  │ │
        │  └────────────────────────────────────┘ │
        └─────────────────────────────────────────┘
```

---

## 🔍 What You Can Monitor

### Access Key Tracking
- Which access key performed which action
- When and from which IP
- Success/failure status
- Resources accessed

### User Activity
- All actions by IAM users
- Assumed role activities
- Root account usage (with alerts!)
- Console logins

### Security Events
- Failed authentication attempts
- Unauthorized access attempts
- Policy changes
- Security group modifications
- Encryption key usage

### Resource Changes
- EC2 instance state changes
- S3 bucket policy changes
- IAM role/user modifications
- Network configuration changes

---

## 📊 Pre-Built Dashboard Features

- **Total Events Counter**: Real-time event count
- **Failed Events Gauge**: Track errors
- **Unique Access Keys**: Number of active keys
- **Events Timeline**: Visual timeline of all activities
- **Events by Access Key**: Pie chart breakdown
- **Top Event Names**: Most common API calls
- **Recent Events Table**: Detailed event log
- **Failed Events Table**: Error tracking
- **Events by Region**: Geographic distribution
- **Events by User Type**: User/Role/Root breakdown

---

## 🚨 Pre-Configured Alerts

1. **Multiple Failed Login Attempts** - Brute force detection
2. **Root Account Usage** - Critical security alert
3. **Unauthorized Access Attempts** - AccessDenied errors
4. **Access Key from Multiple IPs** - Compromised credentials
5. **Security Group Changes** - Network security monitoring
6. **IAM Policy Changes** - Permission modifications
7. **S3 Bucket Policy Changes** - Data exposure prevention
8. **CloudTrail Disabled** - Critical security incident
9. **EC2 State Changes** - Instance monitoring
10. **High API Call Rate** - Unusual activity detection

See **ALERT-RULES.md** for full details and configuration.

---

## 🔧 Customization

### Adjust Processing Frequency
Edit `config.yaml`:
```yaml
interval_seconds: 300  # Check every 5 minutes
```

### Change Log Retention
Edit `config.yaml`:
```yaml
retention_days: 7  # Keep logs for 7 days
```

### Add Custom Parsing
Edit `cloudtrail_processor.py` in the `format_event_for_promtail()` function.

### Add Custom Labels
Edit `promtail-config.yaml` in the `pipeline_stages` section.

---

## 📈 Example Queries

### Track Specific Access Key
```logql
{job="cloudtrail", access_key_id="AKIAIOSFODNN7EXAMPLE"}
```

### Failed Events Only
```logql
{job="cloudtrail", success="false"}
```

### Root Account Activity
```logql
{job="cloudtrail", user_type="Root"}
```

### Security Group Changes
```logql
{job="cloudtrail", event_name=~"AuthorizeSecurityGroupIngress|RevokeSecurityGroupIngress"}
```

See **QUERY-EXAMPLES.md** for 100+ more examples!

---

## 🛠️ Troubleshooting

### No logs appearing?
```bash
# Check processor status
sudo systemctl status cloudtrail-processor

# Check Promtail status
sudo systemctl status promtail

# View logs
sudo journalctl -u cloudtrail-processor -f
```

### Can't connect to S3?
```bash
# Test S3 access
aws s3 ls s3://your-cloudtrail-bucket/

# Check IAM role
aws sts get-caller-identity
```

### Can't connect to Loki?
```bash
# Test from EC2 #1
curl http://LOKI-IP:3100/ready
```

See individual documentation files for detailed troubleshooting.

---

## 💰 Cost Optimization

- **EC2 #1**: Use t3.micro or t3.small (~$7-15/month)
- **S3 Storage**: Use lifecycle policies to archive old logs
- **VPC Endpoint**: Use S3 VPC endpoint to avoid data transfer charges
- **Log Retention**: Adjust retention to balance storage vs. compliance needs

---

## 🔒 Security Best Practices

✅ Use IAM roles instead of access keys  
✅ Restrict security groups to minimum required  
✅ Enable CloudTrail log file validation  
✅ Use VPC endpoints for S3 access  
✅ Encrypt logs at rest and in transit  
✅ Set up alerts for suspicious activities  
✅ Regularly review access patterns  
✅ Keep instances in private subnets  
✅ Enable VPC Flow Logs  
✅ Use AWS Systems Manager for access (no SSH)  

---

## 📚 File Reading Order

**For Quick Setup**:
1. README.md (overview)
2. QUICKSTART.md (installation)
3. IAM-POLICY.md (permissions)
4. SECURITY-GROUPS.md (networking)

**For Configuration**:
1. config.yaml
2. promtail-config.yaml

**For Monitoring**:
1. grafana-cloudtrail-dashboard.json (import to Grafana)
2. ALERT-RULES.md (set up alerts)
3. QUERY-EXAMPLES.md (custom queries)

---

## 🎓 Learning Resources

### Understanding the Components

- **CloudTrail**: AWS service that logs all API calls
- **S3**: Storage for CloudTrail logs (JSON.gz files)
- **Python Script**: Downloads and parses CloudTrail logs
- **Promtail**: Log shipper that sends logs to Loki
- **Loki**: Log aggregation system (like Elasticsearch for logs)
- **Grafana**: Visualization and alerting platform

### How It Works

1. CloudTrail logs every AWS API call to S3
2. Python script downloads new logs every 5 minutes
3. Script parses JSON and extracts important fields
4. Script writes formatted logs to local files
5. Promtail reads these files and adds labels
6. Promtail pushes logs to Loki
7. Grafana queries Loki to display dashboards
8. Alerts trigger based on log patterns

---

## 🆘 Support & Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| No logs in Grafana | Check QUICKSTART.md troubleshooting section |
| S3 access denied | Review IAM-POLICY.md |
| Can't connect to Loki | Check SECURITY-GROUPS.md |
| High CPU usage | Adjust interval in config.yaml |
| Disk full | Reduce retention_days in config.yaml |

### Log Files to Check

```bash
# CloudTrail processor
sudo journalctl -u cloudtrail-processor -f

# Promtail
sudo journalctl -u promtail -f

# Processed files
ls -lh /var/log/cloudtrail-processed/
```

---

## 📝 License & Credits

This package is provided as-is for monitoring AWS CloudTrail logs.

**Technologies Used**:
- Python 3
- AWS SDK (boto3)
- Promtail (Grafana Labs)
- Loki (Grafana Labs)
- Grafana (Grafana Labs)

---

## 🎯 Next Steps After Installation

1. ✅ Import Grafana dashboard
2. ✅ Set up alert rules (ALERT-RULES.md)
3. ✅ Configure notification channels (Slack/Email)
4. ✅ Review security group rules
5. ✅ Test alerts by triggering events
6. ✅ Customize dashboard for your needs
7. ✅ Create team-specific views
8. ✅ Set up regular reviews of access patterns

---

## 📞 Quick Reference Commands

```bash
# Check service status
sudo systemctl status cloudtrail-processor
sudo systemctl status promtail

# View logs
sudo journalctl -u cloudtrail-processor -f
sudo journalctl -u promtail -f

# Restart services
sudo systemctl restart cloudtrail-processor
sudo systemctl restart promtail

# Check processed files
ls -lh /var/log/cloudtrail-processed/

# Test S3 access
aws s3 ls s3://your-bucket/

# Test Loki connection
curl https://16.24.169.121:3100/ready

# Edit configuration
sudo nano /opt/cloudtrail-processor/config.yaml
sudo nano /etc/promtail/promtail-config.yaml
```

---

## 🎉 You're All Set!

This package gives you complete visibility into your AWS environment. You can now:

- 👀 See who is doing what in your AWS account
- 🔑 Track all access key usage
- 🚨 Get alerted on suspicious activities
- 📊 Visualize all CloudTrail events
- 🔍 Search and filter by any criteria
- 📈 Analyze usage patterns
- ✅ Meet compliance requirements

**Happy Monitoring!** 🚀
