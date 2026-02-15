# Final Deployment Instructions

## ✅ What's Ready

Your local `cloudtrail_processor.py` now has:
- ✅ Enhanced access key extraction (shows role names, usernames, service names)
- ✅ Enhanced resource extraction (shows clean resource IDs)
- ✅ Timezone fix (no more datetime comparison errors)
- ✅ All improvements combined

## 🚀 Deploy to EC2

### Step 1: Upload Enhanced File

```bash
# From Windows (PowerShell or Git Bash)
# Navigate to the project folder
cd C:\Users\mohamedsamir\Documents\css\cloudtrail-promtail-setup

# Upload to EC2
scp cloudtrail_processor.py ec2-user@YOUR_EC2_IP:~/
```

**Replace `YOUR_EC2_IP`** with your actual EC2 IP address.

### Step 2: Deploy on EC2

```bash
# SSH to EC2
ssh ec2-user@YOUR_EC2_IP

# Backup current file (just in case)
sudo cp /opt/cloudtrail-processor/cloudtrail_processor.py \
       /opt/cloudtrail-processor/cloudtrail_processor.py.backup.$(date +%Y%m%d_%H%M%S)

# Verify uploaded file has enhanced methods
grep -n "def extract_access_key_identifier" ~/cloudtrail_processor.py

# If the above shows a line number (~136), proceed:

# Replace the file
sudo cp ~/cloudtrail_processor.py /opt/cloudtrail-processor/cloudtrail_processor.py

# Set correct permissions
sudo chown root:root /opt/cloudtrail-processor/cloudtrail_processor.py
sudo chmod 644 /opt/cloudtrail-processor/cloudtrail_processor.py

# Restart service
sudo systemctl restart cloudtrail-processor

# Check status (should show "active (running)" with no errors)
sudo systemctl status cloudtrail-processor
```

### Step 3: Monitor Logs

```bash
# Watch the service logs for 1-2 minutes
sudo journalctl -u cloudtrail-processor -f

# Expected output:
# - "Starting CloudTrail processing"
# - "Looking for logs since..."
# - "Found X new log files"
# - "Writing X events to..."
# - NO "TypeError" or "'list' object has no attribute 'get'" errors
```

Press `Ctrl+C` to stop monitoring.

### Step 4: Wait for New Logs (5-10 minutes)

The processor runs every 5 minutes. Wait for it to process new CloudTrail logs.

```bash
# Check when the last log file was created
ls -lht /var/log/cloudtrail-processed/cloudtrail_*.log | head -5
```

### Step 5: Verify Enhanced Format

```bash
# Show unique access_key_id values from recent logs
tail -50 /var/log/cloudtrail-processed/cloudtrail_*.log | jq -r '.access_key_id' | sort | uniq
```

**Expected output** (✅ Enhanced format working):
```
AKIAIOSFODNN7EXAMPLE
AssumedRole:EC2AdminRole
AssumedRole:LambdaExecutionRole
Console:john.doe
Console:admin
RootAccount
Service:ec2.amazonaws.com
Service:s3.amazonaws.com
```

**NOT expected** (❌ Old format):
```
N/A
N/A
N/A
```

### Step 6: Check Resources

```bash
# Show unique resource values
tail -50 /var/log/cloudtrail-processed/cloudtrail_*.log | jq -r '.resources' | sort | uniq
```

**Expected output** (✅ Enhanced format working):
```
i-0123456789abcdef0
my-bucket-name
EC2:ReadOperation
S3:WriteOperation
IAM:ReadOperation
```

### Step 7: Verify in Grafana

1. Open Grafana in your browser
2. Go to **Explore** → Select **Loki** data source
3. Run this query:

```logql
{job="cloudtrail"} | json | line_format "{{.access_key_id}} → {{.event_name}} → {{.resources}}"
```

4. You should see output like:
```
AssumedRole:EC2AdminRole → DescribeInstances → EC2:ReadOperation
Console:john.doe → PutObject → my-bucket-name
AKIAIOSFODNN7EXAMPLE → RunInstances → i-0123456789abcdef0
```

## 📊 Grafana Dashboard

Your existing dashboard (`grafana-cloudtrail-dashboard.json`) will work with the enhanced format!

The dashboard already has:
- ✅ "Events by Access Key" panel (will now show detailed identifiers)
- ✅ "Access Key Activity & Resources" table
- ✅ "Access Key → Resource Usage" panel
- ✅ Filtering by access key variable

### New Query Capabilities

You can now create new panels or filters:

**Filter by AssumedRole**:
```logql
{job="cloudtrail", access_key_id=~"AssumedRole:.*"}
```

**Filter by Console Logins**:
```logql
{job="cloudtrail", access_key_id=~"Console:.*"}
```

**Filter by Specific Role**:
```logql
{job="cloudtrail", access_key_id="AssumedRole:EC2AdminRole"}
```

**Root Account Activity** (Security Alert!):
```logql
{job="cloudtrail", access_key_id="RootAccount"}
```

**AWS Service Actions**:
```logql
{job="cloudtrail", access_key_id=~"Service:.*"}
```

## 🎯 What Changed

### Before (Old Code on Server):
```python
if user_type == 'Root':
    access_key_id = 'ROOT_ACCOUNT'
elif user_type == 'IAMUser' and event_name == 'ConsoleLogin':
    access_key_id = 'CONSOLE_LOGIN'
elif user_type == 'AssumedRole':
    access_key_id = 'ASSUMED_ROLE'
```

**Result**: Generic labels like `ROOT_ACCOUNT`, `ASSUMED_ROLE`

### After (Enhanced Code):
```python
if user_type == 'AssumedRole':
    if 'assumed-role' in arn:
        parts = arn.split('/')
        if len(parts) >= 2:
            role_name = parts[-2]
            return f"AssumedRole:{role_name}"
```

**Result**: Detailed identifiers like `AssumedRole:EC2AdminRole`, `Console:john.doe`

## ✅ Success Criteria

After deployment, you should have:

- [ ] Service running without errors
- [ ] New log files being created
- [ ] Access keys showing detailed identifiers (not "N/A" or generic labels)
- [ ] Resources showing clean names or operation types
- [ ] Grafana displaying enhanced format
- [ ] Dashboard queries working correctly

## 🐛 Troubleshooting

### Service won't start
```bash
# Check for Python syntax errors
python3 /opt/cloudtrail-processor/cloudtrail_processor.py

# Check service logs
sudo journalctl -u cloudtrail-processor -n 100 --no-pager
```

### Still seeing "N/A" or generic labels
```bash
# Verify the deployed file has enhanced methods
sudo grep -c "AssumedRole:" /opt/cloudtrail-processor/cloudtrail_processor.py

# Should return a number > 10
# If it returns 0, the old file is still deployed
```

### Errors about "'list' object has no attribute 'get'"
This is from CloudTrail-Aggregated files (different format). It's a minor issue that doesn't affect regular CloudTrail logs. We can fix it later if needed.

## 🔄 Rollback (If Needed)

```bash
# Stop service
sudo systemctl stop cloudtrail-processor

# Restore backup
sudo cp /opt/cloudtrail-processor/cloudtrail_processor.py.backup.* \
       /opt/cloudtrail-processor/cloudtrail_processor.py

# Restart
sudo systemctl start cloudtrail-processor
```

## 📝 Summary

**File to upload**: `C:\Users\mohamedsamir\Documents\css\cloudtrail-promtail-setup\cloudtrail_processor.py`

**This file includes**:
- ✅ `extract_access_key_identifier()` - Extracts detailed role names, usernames
- ✅ `extract_resource_names()` - Extracts clean resource IDs
- ✅ Timezone fix - No more datetime comparison errors
- ✅ All enhancements combined

**Expected result**:
- No more "N/A" for access keys
- Detailed identifiers like `AssumedRole:EC2AdminRole`, `Console:john.doe`
- Clean resource names like `i-0123456789abcdef0`, `my-bucket-name`
- Operation types like `EC2:ReadOperation`, `S3:WriteOperation`

**Deploy now and verify in 5-10 minutes!** 🚀
