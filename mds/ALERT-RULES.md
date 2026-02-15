# Grafana Alert Rules for CloudTrail Monitoring

## Overview

This document contains pre-configured alert rules for common security and operational scenarios.

---

## Alert Rule 1: Failed Login Attempts

**Purpose**: Detect multiple failed login attempts (potential brute force)

**Query**:
```logql
sum(count_over_time({job="cloudtrail", event_name="ConsoleLogin", success="false"}[5m])) > 3
```

**Configuration**:
- **Name**: Multiple Failed Login Attempts
- **Evaluate every**: 1m
- **For**: 5m
- **Severity**: Warning
- **Message**: 
  ```
  {{ $value }} failed login attempts detected in the last 5 minutes.
  This could indicate a brute force attack.
  ```

---

## Alert Rule 2: Root Account Usage

**Purpose**: Alert when root account is used (should be avoided)

**Query**:
```logql
sum(count_over_time({job="cloudtrail", user_type="Root"}[5m])) > 0
```

**Configuration**:
- **Name**: Root Account Activity Detected
- **Evaluate every**: 1m
- **For**: 0m (immediate)
- **Severity**: Critical
- **Message**: 
  ```
  Root account activity detected!
  Root account should not be used for daily operations.
  Review CloudTrail logs immediately.
  ```

---

## Alert Rule 3: Unauthorized Access Attempts

**Purpose**: Detect AccessDenied errors (potential unauthorized access)

**Query**:
```logql
sum(count_over_time({job="cloudtrail", error_code="AccessDenied"}[10m])) > 10
```

**Configuration**:
- **Name**: High Number of Access Denied Errors
- **Evaluate every**: 2m
- **For**: 5m
- **Severity**: Warning
- **Message**: 
  ```
  {{ $value }} AccessDenied errors in the last 10 minutes.
  Possible unauthorized access attempts or misconfigured permissions.
  ```

---

## Alert Rule 4: Unusual Access Key Activity

**Purpose**: Detect when an access key is used from multiple IPs

**Query**:
```logql
count(count by (source_ip) (count_over_time({job="cloudtrail", access_key_id=~".+"}[1h]))) > 5
```

**Configuration**:
- **Name**: Access Key Used from Multiple IPs
- **Evaluate every**: 5m
- **For**: 10m
- **Severity**: Warning
- **Message**: 
  ```
  An access key has been used from {{ $value }} different IP addresses in the last hour.
  This could indicate compromised credentials.
  ```

---

## Alert Rule 5: Security Group Changes

**Purpose**: Alert on security group modifications

**Query**:
```logql
sum(count_over_time({job="cloudtrail", event_name=~"AuthorizeSecurityGroupIngress|RevokeSecurityGroupIngress|AuthorizeSecurityGroupEgress|RevokeSecurityGroupEgress"}[5m])) > 0
```

**Configuration**:
- **Name**: Security Group Modified
- **Evaluate every**: 1m
- **For**: 0m
- **Severity**: Warning
- **Message**: 
  ```
  Security group has been modified.
  Review the changes to ensure they are authorized.
  ```

---

## Alert Rule 6: IAM Policy Changes

**Purpose**: Alert on IAM policy modifications

**Query**:
```logql
sum(count_over_time({job="cloudtrail", event_name=~"PutUserPolicy|PutRolePolicy|PutGroupPolicy|DeleteUserPolicy|DeleteRolePolicy|DeleteGroupPolicy|CreatePolicy|DeletePolicy"}[5m])) > 0
```

**Configuration**:
- **Name**: IAM Policy Modified
- **Evaluate every**: 1m
- **For**: 0m
- **Severity**: High
- **Message**: 
  ```
  IAM policy has been created, modified, or deleted.
  Review the changes immediately for security compliance.
  ```

---

## Alert Rule 7: S3 Bucket Policy Changes

**Purpose**: Alert on S3 bucket policy modifications

**Query**:
```logql
sum(count_over_time({job="cloudtrail", event_name=~"PutBucketPolicy|DeleteBucketPolicy|PutBucketAcl"}[5m])) > 0
```

**Configuration**:
- **Name**: S3 Bucket Policy Modified
- **Evaluate every**: 1m
- **For**: 0m
- **Severity**: High
- **Message**: 
  ```
  S3 bucket policy or ACL has been modified.
  Verify the changes to prevent data exposure.
  ```

---

## Alert Rule 8: CloudTrail Disabled

**Purpose**: Alert if CloudTrail is stopped or deleted

**Query**:
```logql
sum(count_over_time({job="cloudtrail", event_name=~"StopLogging|DeleteTrail"}[5m])) > 0
```

**Configuration**:
- **Name**: CloudTrail Logging Disabled
- **Evaluate every**: 1m
- **For**: 0m
- **Severity**: Critical
- **Message**: 
  ```
  CRITICAL: CloudTrail logging has been stopped or deleted!
  This is a serious security incident. Investigate immediately.
  ```

---

## Alert Rule 9: EC2 Instance State Changes

**Purpose**: Monitor EC2 instance starts/stops

**Query**:
```logql
sum(count_over_time({job="cloudtrail", event_name=~"RunInstances|TerminateInstances|StopInstances|StartInstances"}[5m])) > 0
```

**Configuration**:
- **Name**: EC2 Instance State Changed
- **Evaluate every**: 2m
- **For**: 0m
- **Severity**: Info
- **Message**: 
  ```
  EC2 instance state has changed (started, stopped, or terminated).
  Review for unauthorized changes.
  ```

---

## Alert Rule 10: High API Call Rate

**Purpose**: Detect unusual spike in API calls (potential attack or misconfiguration)

**Query**:
```logql
sum(count_over_time({job="cloudtrail"}[5m])) > 1000
```

**Configuration**:
- **Name**: High API Call Rate
- **Evaluate every**: 1m
- **For**: 5m
- **Severity**: Warning
- **Message**: 
  ```
  {{ $value }} API calls detected in the last 5 minutes.
  This is unusually high. Check for automated scripts or potential attacks.
  ```

---

## How to Import Alert Rules in Grafana

### Method 1: Via UI

1. Go to **Alerting** → **Alert rules** in Grafana
2. Click **New alert rule**
3. Fill in the details from each rule above:
   - **Query**: Use the LogQL query provided
   - **Condition**: Set threshold as specified
   - **Evaluation**: Set evaluation interval and duration
4. Add **Labels** (e.g., `severity: critical`)
5. Add **Annotations** with the message template
6. Click **Save**

### Method 2: Via Provisioning

Create a file `/etc/grafana/provisioning/alerting/cloudtrail-alerts.yaml`:

```yaml
apiVersion: 1

groups:
  - name: cloudtrail-security
    interval: 1m
    rules:
      - uid: failed-logins
        title: Multiple Failed Login Attempts
        condition: A
        data:
          - refId: A
            queryType: ''
            relativeTimeRange:
              from: 300
              to: 0
            datasourceUid: loki-uid
            model:
              expr: 'sum(count_over_time({job="cloudtrail", event_name="ConsoleLogin", success="false"}[5m])) > 3'
        for: 5m
        annotations:
          description: '{{ $value }} failed login attempts detected in the last 5 minutes.'
        labels:
          severity: warning
      
      - uid: root-account-usage
        title: Root Account Activity Detected
        condition: A
        data:
          - refId: A
            queryType: ''
            relativeTimeRange:
              from: 300
              to: 0
            datasourceUid: loki-uid
            model:
              expr: 'sum(count_over_time({job="cloudtrail", user_type="Root"}[5m])) > 0'
        for: 0m
        annotations:
          description: 'Root account activity detected! Review immediately.'
        labels:
          severity: critical
```

Then restart Grafana:
```bash
sudo systemctl restart grafana-server
```

---

## Notification Channels

### Configure Slack Notifications

1. Go to **Alerting** → **Contact points**
2. Click **New contact point**
3. Select **Slack**
4. Enter webhook URL
5. Test and save

### Configure Email Notifications

1. Edit `/etc/grafana/grafana.ini`:
   ```ini
   [smtp]
   enabled = true
   host = smtp.gmail.com:587
   user = your-email@gmail.com
   password = your-app-password
   from_address = your-email@gmail.com
   from_name = Grafana CloudTrail Alerts
   ```

2. Restart Grafana:
   ```bash
   sudo systemctl restart grafana-server
   ```

3. Create email contact point in Grafana UI

---

## Alert Testing

Test alerts manually:

```bash
# Generate failed login (will fail but create log)
aws sts get-caller-identity --profile invalid-profile

# Check if alert triggered in Grafana
# Go to Alerting → Alert rules → Check state
```

---

## Best Practices

1. **Start with Critical Alerts**: Implement root account and CloudTrail disabled alerts first
2. **Tune Thresholds**: Adjust based on your environment's normal activity
3. **Avoid Alert Fatigue**: Don't set too many low-priority alerts
4. **Test Regularly**: Ensure alerts are working as expected
5. **Document Response**: Create runbooks for each alert type
6. **Review Periodically**: Update rules based on new threats and patterns

---

## Custom Alert Examples

### Alert on Specific User Activity

```logql
sum(count_over_time({job="cloudtrail", principal_id=~".*specific-user.*"}[5m])) > 0
```

### Alert on Specific Resource Access

```logql
{job="cloudtrail"} |~ "arn:aws:s3:::sensitive-bucket"
```

### Alert on After-Hours Activity

```logql
sum(count_over_time({job="cloudtrail"}[5m])) > 10 and hour() < 6 or hour() > 18
```

---

## Troubleshooting Alerts

### Alert Not Firing

1. Check query in **Explore**:
   ```logql
   sum(count_over_time({job="cloudtrail"}[5m]))
   ```

2. Verify data is flowing:
   ```logql
   {job="cloudtrail"}
   ```

3. Check alert rule state in **Alerting** → **Alert rules**

### Too Many False Positives

- Increase threshold values
- Increase evaluation time window
- Add more specific filters to queries

### Missing Alerts

- Decrease evaluation interval
- Check notification channel configuration
- Verify contact points are working
