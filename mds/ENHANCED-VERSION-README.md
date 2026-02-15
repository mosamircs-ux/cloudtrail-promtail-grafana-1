# CloudTrail Processor - Enhanced Version

## Changes Made

### 1. Enhanced Access Key Extraction

**New Method**: `extract_access_key_identifier(user_identity)`

This method replaces the simple `user_identity.get('accessKeyId', 'N/A')` with intelligent extraction:

- **Access Keys**: Returns actual access key (e.g., `AKIAIOSFODNN7EXAMPLE`)
- **AssumedRole**: Returns `AssumedRole:RoleName` (e.g., `AssumedRole:EC2AdminRole`)
- **Console Login**: Returns `Console:username` (e.g., `Console:john.doe`)
- **Root Account**: Returns `RootAccount`
- **AWS Service**: Returns `Service:servicename` (e.g., `Service:ec2.amazonaws.com`)
- **Federated User**: Returns `Federated:username`
- **SAML User**: Returns `SAML:principalId`

### 2. Enhanced Resource Extraction

**New Method**: `extract_resource_names(event)`

This method provides comprehensive resource extraction:

**From Resource ARNs**:
- EC2 instances: `i-0123456789abcdef0`
- S3 buckets: `my-bucket-name`
- RDS databases: `my-database`
- Lambda functions: `my-function`
- EBS volumes: `vol-0123456789abcdef0`
- Security groups: `sg-0123456789abcdef0`

**From Request Parameters**:
- EC2: `instanceId`, `instancesSet`
- S3: `bucketName`
- RDS: `dBInstanceIdentifier`, `dBClusterIdentifier`
- Lambda: `functionName`
- EBS: `volumeId`
- Security Groups: `groupId`
- IAM: `userName`, `roleName`, `policyName`

**For Read Operations** (Describe/List/Get):
- Returns `SERVICE:ReadOperation` (e.g., `EC2:ReadOperation`)

**For Write Operations** (Create/Delete/Update/Modify/Put):
- Returns `SERVICE:WriteOperation` (e.g., `S3:WriteOperation`)

### 3. Updated format_event_for_promtail

The main formatting method now uses the new extraction methods, resulting in:
- No more "N/A" for access keys (replaced with descriptive identifiers)
- Better resource identification
- More meaningful log entries

## Benefits

✅ **Complete Visibility**: Every action has an identifier  
✅ **Better Security Tracking**: Distinguish between users, roles, and services  
✅ **Easier Filtering**: Filter by identity type in Grafana  
✅ **Improved Auditing**: Clear audit trail for compliance  
✅ **No IAM Changes**: Works with existing permissions  

## Examples

### Before
```json
{
  "access_key_id": "N/A",
  "event_name": "DescribeInstances",
  "resources": "N/A"
}
```

### After
```json
{
  "access_key_id": "AssumedRole:EC2AdminRole",
  "event_name": "DescribeInstances",
  "resources": "EC2:ReadOperation"
}
```

## Deployment

### Prerequisites
- Backup current `cloudtrail_processor.py`
- Ensure CloudTrail processor service is running
- Verify IAM permissions (S3 read access to CloudTrail bucket)

### Steps

1. **Backup current file**:
   ```bash
   sudo cp /opt/cloudtrail-processor/cloudtrail_processor.py \
          /opt/cloudtrail-processor/cloudtrail_processor.py.backup.$(date +%Y%m%d)
   ```

2. **Upload new file to EC2**:
   ```bash
   scp cloudtrail_processor.py ec2-user@YOUR_EC2_IP:~/
   ```

3. **Replace current file**:
   ```bash
   ssh ec2-user@YOUR_EC2_IP
   sudo cp ~/cloudtrail_processor.py /opt/cloudtrail-processor/cloudtrail_processor.py
   sudo chown root:root /opt/cloudtrail-processor/cloudtrail_processor.py
   sudo chmod 644 /opt/cloudtrail-processor/cloudtrail_processor.py
   ```

4. **Restart service**:
   ```bash
   sudo systemctl restart cloudtrail-processor
   sudo systemctl status cloudtrail-processor
   ```

5. **Monitor logs**:
   ```bash
   sudo journalctl -u cloudtrail-processor -f
   ```

### Verification

Wait 5-10 minutes for new logs to be processed, then:

```bash
# Check recent logs
tail -20 /var/log/cloudtrail-processed/cloudtrail_*.log | jq '.access_key_id'

# Expected output: Mix of actual keys, AssumedRole:XXX, Console:XXX, etc.
```

## Grafana Dashboard Updates

### New Query Patterns

**Filter by AssumedRole**:
```logql
{job="cloudtrail", access_key_id=~"AssumedRole:.*"}
```

**Filter by Console Logins**:
```logql
{job="cloudtrail", access_key_id=~"Console:.*"}
```

**Filter by Actual Access Keys**:
```logql
{job="cloudtrail", access_key_id=~"AKIA.*"}
```

**Filter by Root Account** (Security Alert!):
```logql
{job="cloudtrail", access_key_id="RootAccount"}
```

**Filter by AWS Services**:
```logql
{job="cloudtrail", access_key_id=~"Service:.*"}
```

### Update Existing Queries

Replace:
```logql
{job="cloudtrail", access_key_id!="N/A"}
```

With:
```logql
{job="cloudtrail", access_key_id!~"Unknown"}
```

## Rollback Procedure

If issues occur:

```bash
# Stop service
sudo systemctl stop cloudtrail-processor

# Restore backup
sudo cp /opt/cloudtrail-processor/cloudtrail_processor.py.backup.* \
       /opt/cloudtrail-processor/cloudtrail_processor.py

# Restart service
sudo systemctl start cloudtrail-processor
sudo systemctl status cloudtrail-processor
```

## Troubleshooting

### Service won't start
```bash
# Check syntax errors
python3 /opt/cloudtrail-processor/cloudtrail_processor.py --help

# Check logs
sudo journalctl -u cloudtrail-processor -n 50
```

### No new logs appearing
```bash
# Check processor is running
sudo systemctl status cloudtrail-processor

# Check S3 access
aws s3 ls s3://aws-cloudtrail-logs-124737196430-56a3b94b/

# Check state file
cat /var/lib/promtail/cloudtrail-state.json
```

### Still seeing "N/A" in Grafana
- Old logs will still have "N/A" (this is expected)
- New logs (after restart) should have enhanced identifiers
- Check timestamp of logs in Grafana
- Verify time range includes recent data

## Notes

- Historical data will still show "N/A"
- Only new logs (after deployment) will use enhanced format
- No AWS API calls are made - only log parsing is enhanced
- IAM permissions remain unchanged
- Compatible with existing Promtail and Loki setup

## Support

For issues or questions:
1. Check service logs: `sudo journalctl -u cloudtrail-processor -f`
2. Verify file syntax: `python3 cloudtrail_processor.py`
3. Review this documentation
4. Check Grafana query syntax
