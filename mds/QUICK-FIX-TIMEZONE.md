# Quick Fix - Timezone Comparison Error

## Issue
After deployment, the service showed this error:
```
TypeError: can't compare offset-naive and offset-aware datetimes
```

## Root Cause
The datetime comparison on line 95 was comparing:
- `obj['LastModified']` (timezone-aware from S3)
- `start_time` (could be timezone-aware from state file)

## Fix Applied
Changed line 59 to ensure `start_time` is always timezone-naive:

```python
# Before
start_time = datetime.fromisoformat(state['last_processed_time'])

# After
start_time = datetime.fromisoformat(state['last_processed_time']).replace(tzinfo=None)
```

This matches the existing line 95 which already strips timezone info from S3's `LastModified`.

## How to Apply

### Option 1: Re-upload the fixed file

```bash
# From your local machine
scp cloudtrail_processor.py ec2-user@YOUR_EC2_IP:~/

# On EC2
ssh ec2-user@YOUR_EC2_IP
sudo cp ~/cloudtrail_processor.py /opt/cloudtrail-processor/cloudtrail_processor.py
sudo systemctl restart cloudtrail-processor
sudo systemctl status cloudtrail-processor
```

### Option 2: Quick patch on EC2

```bash
# SSH to EC2
ssh ec2-user@YOUR_EC2_IP

# Edit the file
sudo nano /opt/cloudtrail-processor/cloudtrail_processor.py

# Find line 59 (around line 59):
# Change:
start_time = datetime.fromisoformat(state['last_processed_time'])

# To:
start_time = datetime.fromisoformat(state['last_processed_time']).replace(tzinfo=None)

# Save (Ctrl+O, Enter, Ctrl+X)

# Restart service
sudo systemctl restart cloudtrail-processor
sudo systemctl status cloudtrail-processor
```

## Verification

After applying the fix:

```bash
# Check service status (should show "active (running)" with no errors)
sudo systemctl status cloudtrail-processor

# Monitor logs for a minute
sudo journalctl -u cloudtrail-processor -f

# Should see:
# - "Starting CloudTrail processing"
# - "Looking for logs since..."
# - "Found X new log files" or "No new files to process"
# - No TypeError errors
```

## Status

✅ **Fix applied to local file**  
⏳ **Needs re-upload to EC2**  

The fixed `cloudtrail_processor.py` is ready in your local folder.
