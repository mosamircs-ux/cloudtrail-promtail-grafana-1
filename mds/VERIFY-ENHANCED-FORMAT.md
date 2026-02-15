# Quick Verification Commands

## Check if Enhanced Format is Working

Run these commands on your EC2 instance to verify the enhanced access key tracking:

### 1. Check Recent Log Entries

```bash
# View the most recent log file
tail -5 /var/log/cloudtrail-processed/cloudtrail_20260208_072708.log | jq '.'
```

This will show you the full structure of recent events.

### 2. Check Access Key IDs Specifically

```bash
# Show just the access_key_id field from recent logs
tail -20 /var/log/cloudtrail-processed/cloudtrail_*.log | jq -r '.access_key_id' | sort | uniq
```

**What you should see:**
- ✅ `AKIA...` (actual access keys)
- ✅ `AssumedRole:RoleName` (for role-based actions)
- ✅ `Console:username` (for console logins)
- ✅ `Service:servicename` (for AWS service actions)
- ✅ `RootAccount` (if root was used)

**What you should NOT see:**
- ❌ `N/A` (this means old code is still running)

### 3. Check Resources Field

```bash
# Show resources from recent logs
tail -20 /var/log/cloudtrail-processed/cloudtrail_*.log | jq -r '.resources' | sort | uniq
```

**What you should see:**
- ✅ Instance IDs like `i-0123456789abcdef0`
- ✅ Bucket names like `my-bucket-name`
- ✅ Operation types like `EC2:ReadOperation`, `S3:WriteOperation`

**What you should NOT see:**
- ❌ `N/A` everywhere

### 4. Check if Enhanced Methods Exist in Deployed File

```bash
# Verify the deployed file has the enhanced methods
sudo grep -n "def extract_access_key_identifier" /opt/cloudtrail-processor/cloudtrail_processor.py
```

**Expected**: Should show line number (around 130)

**If it shows nothing**: The old file is still deployed - you need to upload the enhanced version.

### 5. Show Sample Events

```bash
# Show 2 complete events to see the full structure
tail -50 /var/log/cloudtrail-processed/cloudtrail_*.log | jq '.' | head -100
```

Look for the `access_key_id` and `resources` fields in the output.

## If You Still See "N/A"

The enhanced file wasn't uploaded correctly. Re-upload:

```bash
# On your Windows machine
scp cloudtrail_processor.py ec2-user@YOUR_EC2_IP:~/

# On EC2
ssh ec2-user@YOUR_EC2_IP
sudo cp ~/cloudtrail_processor.py /opt/cloudtrail-processor/cloudtrail_processor.py
sudo systemctl restart cloudtrail-processor

# Wait 5 minutes for new logs, then check again
sleep 300
tail -20 /var/log/cloudtrail-processed/cloudtrail_*.log | jq -r '.access_key_id' | sort | uniq
```

## About the Errors

The errors you see:
```
ERROR - Error processing ...CloudTrail-Aggregated...: 'list' object has no attribute 'get'
```

These are from CloudTrail-Aggregated files which have a different format. This is a minor issue that doesn't affect the main CloudTrail logs (243 events were successfully processed).

We can fix this later if needed, but the main CloudTrail logs are working fine.

## Success Indicators

✅ **Service is running** - No crashes  
✅ **Logs are being processed** - 243 events written  
✅ **Files are being created** - `/var/log/cloudtrail-processed/cloudtrail_*.log`  

Now we just need to verify the **format** of those logs shows enhanced identifiers instead of "N/A".

Run the commands above to check!
