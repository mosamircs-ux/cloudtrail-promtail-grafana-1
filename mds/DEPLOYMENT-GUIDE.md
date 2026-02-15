# Deployment Guide - Enhanced CloudTrail Processor

## ✅ Implementation Complete

The enhanced CloudTrail processor has been successfully implemented with the following changes:

### Changes Made

1. **Added `extract_access_key_identifier()` method**
   - Extracts meaningful identifiers for all AWS identity types
   - Returns descriptive values instead of "N/A"

2. **Added `extract_resource_names()` method**
   - Enhanced resource extraction from CloudTrail events
   - Supports EC2, S3, RDS, Lambda, EBS, Security Groups, IAM
   - Returns operation type for Describe/List/Get calls

3. **Updated `format_event_for_promtail()` method**
   - Uses new extraction methods
   - Produces cleaner, more informative log entries

### Test Results

✅ All unit tests passed successfully:
- Access key extraction: 5/5 tests passed
- Resource extraction: 5/5 tests passed

## Next Steps: Deploy to EC2

### Prerequisites

- SSH access to your EC2 instance
- EC2 instance IP address
- Backup of current processor (recommended)

### Deployment Steps

#### Step 1: Upload File to EC2

```bash
# From your local machine (Windows PowerShell or Git Bash)
scp cloudtrail_processor.py ec2-user@YOUR_EC2_IP:~/
```

**Replace `YOUR_EC2_IP`** with your actual EC2 instance IP address.

#### Step 2: SSH to EC2 and Backup Current File

```bash
# SSH to EC2
ssh ec2-user@YOUR_EC2_IP

# Create backup with timestamp
sudo cp /opt/cloudtrail-processor/cloudtrail_processor.py \
       /opt/cloudtrail-processor/cloudtrail_processor.py.backup.$(date +%Y%m%d_%H%M%S)

# Verify backup was created
ls -lh /opt/cloudtrail-processor/*.backup*
```

#### Step 3: Replace with Enhanced Version

```bash
# Copy new file to processor directory
sudo cp ~/cloudtrail_processor.py /opt/cloudtrail-processor/cloudtrail_processor.py

# Set correct ownership and permissions
sudo chown root:root /opt/cloudtrail-processor/cloudtrail_processor.py
sudo chmod 644 /opt/cloudtrail-processor/cloudtrail_processor.py

# Verify file was updated
ls -lh /opt/cloudtrail-processor/cloudtrail_processor.py
```

#### Step 4: Restart CloudTrail Processor Service

```bash
# Restart the service
sudo systemctl restart cloudtrail-processor

# Check service status
sudo systemctl status cloudtrail-processor

# Monitor logs for any errors
sudo journalctl -u cloudtrail-processor -f
```

**Expected output**: Service should show "active (running)" status.

Press `Ctrl+C` to stop monitoring logs.

#### Step 5: Wait for New Logs (5-10 minutes)

The processor runs every 5 minutes by default. Wait for it to process new CloudTrail logs.

```bash
# Check when the last log file was created
ls -lht /var/log/cloudtrail-processed/cloudtrail_*.log | head -5
```

#### Step 6: Verify Enhanced Format

```bash
# Check recent logs for enhanced access key identifiers
tail -20 /var/log/cloudtrail-processed/cloudtrail_*.log | jq '.access_key_id'

# Expected output: Mix of values like:
# - "AKIAIOSFODNN7EXAMPLE" (actual access keys)
# - "AssumedRole:EC2AdminRole" (role-based actions)
# - "Console:john.doe" (console logins)
# - "Service:ec2.amazonaws.com" (service actions)
# - "RootAccount" (root account actions)
```

```bash
# Check resource extraction
tail -20 /var/log/cloudtrail-processed/cloudtrail_*.log | jq '.resources'

# Expected output: Resource names or operation types like:
# - "i-0123456789abcdef0" (EC2 instances)
# - "my-bucket-name" (S3 buckets)
# - "EC2:ReadOperation" (describe operations)
# - "S3:WriteOperation" (create operations)
```

#### Step 7: Verify in Grafana

1. Open Grafana in your browser
2. Navigate to **Explore** → Select **Loki** data source
3. Run this query:

```logql
{job="cloudtrail"} | json | line_format "{{.access_key_id}} | {{.resources}}"
```

4. Verify you see enhanced identifiers in the results
5. Check the timestamp - should be recent (within last 10 minutes)

#### Step 8: Update Dashboard Queries (Optional)

If you have existing dashboard queries filtering on `access_key_id!="N/A"`, update them:

**Old query**:
```logql
{job="cloudtrail", access_key_id!="N/A"}
```

**New query** (to exclude only truly unknown identities):
```logql
{job="cloudtrail", access_key_id!~"Unknown"}
```

**Or** (to include all identities):
```logql
{job="cloudtrail"}
```

### New Query Capabilities

You can now filter by identity type:

**All AssumedRole actions**:
```logql
{job="cloudtrail", access_key_id=~"AssumedRole:.*"}
```

**All Console logins**:
```logql
{job="cloudtrail", access_key_id=~"Console:.*"}
```

**All actual access key usage**:
```logql
{job="cloudtrail", access_key_id=~"AKIA.*"}
```

**Root account activity** (Security Alert!):
```logql
{job="cloudtrail", access_key_id="RootAccount"}
```

**AWS Service actions**:
```logql
{job="cloudtrail", access_key_id=~"Service:.*"}
```

## Rollback Procedure

If you encounter any issues:

```bash
# Stop the service
sudo systemctl stop cloudtrail-processor

# Restore the backup (use the actual backup filename)
sudo cp /opt/cloudtrail-processor/cloudtrail_processor.py.backup.YYYYMMDD_HHMMSS \
       /opt/cloudtrail-processor/cloudtrail_processor.py

# Restart the service
sudo systemctl start cloudtrail-processor

# Verify it's running
sudo systemctl status cloudtrail-processor
```

## Troubleshooting

### Service fails to start

```bash
# Check for Python syntax errors
python3 /opt/cloudtrail-processor/cloudtrail_processor.py

# Check service logs
sudo journalctl -u cloudtrail-processor -n 50 --no-pager
```

### No new logs appearing

```bash
# Verify service is running
sudo systemctl status cloudtrail-processor

# Check S3 access
aws s3 ls s3://aws-cloudtrail-logs-124737196430-56a3b94b/

# Check processor state
cat /var/lib/promtail/cloudtrail-state.json | jq
```

### Still seeing "N/A" in Grafana

- **Old logs** will still show "N/A" (this is expected)
- **New logs** (after restart) should have enhanced identifiers
- Check the timestamp in Grafana - ensure you're looking at recent data
- Verify the time range includes data from after the deployment

### Grafana shows no data

```bash
# Check Promtail is running
sudo systemctl status promtail

# Check Promtail logs
sudo journalctl -u promtail -n 50 --no-pager

# Verify Promtail can read the log files
sudo ls -lh /var/log/cloudtrail-processed/
```

## Important Notes

⚠️ **Historical Data**: Old logs will continue to show "N/A" - this is expected and normal  
⚠️ **Time Delay**: New format appears after processor runs (every 5 minutes)  
⚠️ **No IAM Changes**: No additional AWS permissions are required  
⚠️ **Backward Compatible**: Old logs remain readable and queryable  

## Success Criteria

✅ Service restarts without errors  
✅ New log files are created  
✅ Logs contain enhanced access key identifiers  
✅ Resources are properly extracted  
✅ Grafana displays new format  
✅ Dashboard queries work correctly  

## Summary

The enhanced CloudTrail processor provides:

- **Complete visibility** - Every action has an identifier
- **Better security tracking** - Distinguish users, roles, and services
- **Easier filtering** - Filter by identity type in Grafana
- **Improved auditing** - Clear audit trail for compliance
- **No IAM changes** - Works with existing permissions

## Files Created

1. `cloudtrail_processor.py` - Enhanced processor (updated)
2. `ENHANCED-VERSION-README.md` - Detailed documentation
3. `test_enhancements.py` - Test suite
4. `DEPLOYMENT-GUIDE.md` - This file

## Need Help?

If you encounter issues:
1. Check service logs: `sudo journalctl -u cloudtrail-processor -f`
2. Verify file syntax: `python3 /opt/cloudtrail-processor/cloudtrail_processor.py`
3. Review ENHANCED-VERSION-README.md
4. Use rollback procedure if needed

## What's Next?

After successful deployment:
1. Monitor the dashboard for 24 hours
2. Review new query patterns
3. Set up alerts for root account usage
4. Document any custom queries for your team
5. Update team runbooks with new capabilities
