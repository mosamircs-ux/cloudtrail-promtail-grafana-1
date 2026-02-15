# Fix for Resource Extraction - Show All AWS Resources (EC2, S3, etc.)

## Problem

The Grafana dashboard panel "Detailed Activity Log (Who Did What, When, and Where)" was only showing **one resource**:
- `aws-cloudtrail-logs-124737196430-56a3b94b, Unknown`

Instead of showing actual AWS resources like:
- EC2 instances (e.g., `i-0123456789abcdef0`)
- S3 buckets (e.g., `my-app-bucket`)
- RDS databases, Lambda functions, etc.

## Root Cause

The issue was in the `cloudtrail_processor.py` script's `extract_resource_names()` function:

1. **CloudTrail bucket pollution**: The CloudTrail S3 bucket itself was being included in resource lists
2. **Missing DescribeInstances handling**: When you view EC2 instances, CloudTrail logs `DescribeInstances` events which contain instance IDs in the **response**, not the request
3. **Missing response element parsing**: Many AWS operations (like `CreateInstance`, `CreateBucket`) put the resource ID in the **response elements**, not request parameters
4. **Generic fallbacks too early**: The code was falling back to generic labels like "EC2:ReadOperation" before fully exploring all data sources

## Solution Applied

I've enhanced the `cloudtrail_processor.py` script with the following improvements:

### 1. **Filter Out CloudTrail Buckets**
```python
# Skip CloudTrail bucket ARNs (these are just metadata)
if 'cloudtrail-logs' in arn.lower():
    continue
```

### 2. **Enhanced DescribeInstances Support**
The script now extracts instance IDs from:
- Request filters (when querying specific instances)
- Response elements (when describing all instances)

```python
elif event_name == 'DescribeInstances' and 'filterSet' in request_params:
    # Extract from filters or response
    return self._extract_from_describe_instances_response(response_elements)
```

### 3. **New Helper Function**
Added `_extract_from_describe_instances_response()` to parse EC2 response data:
- Navigates the complex nested structure: `reservationSet → items → instancesSet → items → instanceId`
- Limits output to 5 instances (to avoid too-long strings)

### 4. **Response Elements Parsing for Create Operations**
Now checks response elements for newly created resources:
- EC2 instances from `CreateInstance` / `RunInstances`
- S3 buckets from `CreateBucket`
- Lambda functions, RDS instances, etc.

### 5. **Better S3 Object Handling**
Extracts both bucket name and key for S3 object operations

## How to Apply This Fix

### On Your EC2 Instance (Ubuntu)

1. **Upload the updated script**:
```bash
# From your local machine
scp -i your-key.pem c:\Users\mohamedsamir\Documents\css\cloudtrail-promtail-setup\cloudtrail_processor.py ubuntu@YOUR_EC2_IP:/home/ubuntu/
```

2. **SSH to your EC2 instance**:
```bash
ssh -i your-key.pem ubuntu@YOUR_EC2_IP
```

3. **Backup the current script**:
```bash
sudo cp /opt/cloudtrail-processor/cloudtrail_processor.py /opt/cloudtrail-processor/cloudtrail_processor.py.backup
```

4. **Replace with the updated version**:
```bash
sudo cp /home/ubuntu/cloudtrail_processor.py /opt/cloudtrail-processor/cloudtrail_processor.py
sudo chown root:root /opt/cloudtrail-processor/cloudtrail_processor.py
sudo chmod 755 /opt/cloudtrail-processor/cloudtrail_processor.py
```

5. **Restart the service**:
```bash
sudo systemctl restart cloudtrail-processor
```

6. **Verify it's running**:
```bash
sudo systemctl status cloudtrail-processor
sudo journalctl -u cloudtrail-processor -f
```

7. **Wait for new logs to be processed** (default is every 5 minutes)

8. **Check Grafana** - refresh your dashboard and you should now see:
   - EC2 instance IDs (e.g., `i-0123456789abcdef0`)
   - S3 bucket names (your actual buckets, not CloudTrail bucket)
   - Other AWS resources

## What You'll See After the Fix

### Before:
```
Resource: aws-cloudtrail-logs-124737196430-56a3b94b, Unknown
```

### After:
```
Resource: i-0a1b2c3d4e5f6g7h8
Resource: my-production-s3-bucket
Resource: i-0123456789abcdef0, i-0fedcba987654321
Resource: my-app-lambda-function
Resource: EC2:ReadOperation    (for account-level queries like "list all instances")
```

## Expected Behavior

### EC2 Actions
- `RunInstances` → Shows new instance IDs
- `StartInstances` → Shows instance IDs being started
- `StopInstances` → Shows instance IDs being stopped
- `DescribeInstances` → Shows all queried instance IDs (up to 5, then "+N more")

### S3 Actions
- `CreateBucket` → Shows new bucket name
- `PutObject` → Shows `bucket-name/object-key`
- `GetObject` → Shows `bucket-name/object-key`
- `DeleteBucket` → Shows bucket name

### Generic Actions
- `DescribeInstances` (no filter) → Shows first 5 instances found in response
- `ListBuckets` → Shows `S3:ReadOperation` (account-level)
- CloudTrail's own S3 operations → **Filtered out** (no longer shown)

## Troubleshooting

### If resources still show as "Unknown" after applying:

1. **Check the processor is actually running**:
```bash
sudo systemctl status cloudtrail-processor
```

2. **Check for errors in logs**:
```bash
sudo journalctl -u cloudtrail-processor -n 50 --no-pager
```

3. **Verify new logs are being created**:
```bash
ls -lh /var/log/cloudtrail-processed/ | tail -10
```

4. **Check if Promtail is reading the logs**:
```bash
sudo journalctl -u promtail -n 50 --no-pager | grep cloudtrail
```

5. **Test with a manual action**:
   - Go to AWS console and perform a simple action (e.g., stop/start an EC2 instance)
   - Wait 5 minutes for CloudTrail → S3 → Processor → Promtail → Loki → Grafana
   - Check if the new event shows the correct instance ID

### If you still see only CloudTrail bucket:

This means existing logs already have "aws-cloudtrail-logs-..." in them. The fix only affects **newly processed events**. You could:

1. **Wait for new events** (recommended)
2. **Force reprocess** by deleting the state file:
```bash
sudo rm /var/lib/promtail/cloudtrail-state.json
sudo systemctl restart cloudtrail-processor
```

This will reprocess the last 24 hours of logs with the new logic.

## Technical Details

The enhanced function now follows this precedence:

1. **Resources array** (if present and not CloudTrail bucket)
2. **Request parameters** (instanceId, bucketName, etc.)
3. **Response elements** (for Create operations and DescribeInstances)
4. **Generic service-level labels** (ReadOperation, WriteOperation) - only as last resort

This ensures maximum resource visibility while filtering out CloudTrail's own metadata.
