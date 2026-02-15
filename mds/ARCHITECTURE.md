# Architecture & Data Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                                  │
│                                                                     │
│  ┌──────────────────┐                                              │
│  │   CloudTrail     │  Logs all AWS API calls                      │
│  │   (AWS Service)  │  • Who: User/Role/Access Key                 │
│  └────────┬─────────┘  • What: API action                          │
│           │            • When: Timestamp                            │
│           │            • Where: Region, IP                          │
│           │            • Result: Success/Failure                    │
│           │                                                         │
│           ▼                                                         │
│  ┌──────────────────┐                                              │
│  │   S3 Bucket      │  Stores CloudTrail logs                      │
│  │                  │  • JSON.gz format                            │
│  │  my-cloudtrail/  │  • Organized by date                         │
│  │  └─ AWSLogs/     │  • Encrypted at rest                         │
│  │     └─ 2026/     │                                              │
│  │        └─ 02/    │                                              │
│  │           └─ 03/ │                                              │
│  └────────┬─────────┘                                              │
│           │                                                         │
└───────────┼─────────────────────────────────────────────────────────┘
            │
            │ IAM Role: S3 Read Access
            │ Protocol: HTTPS (443)
            │ Frequency: Every 5 minutes
            │
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  EC2 #1: CloudTrail Processor (t3.small)                           │
│  Private IP: 10.0.1.10                                              │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Python Script: cloudtrail_processor.py                       │ │
│  │  ────────────────────────────────────────────────────────────  │ │
│  │  1. List new CloudTrail files from S3                         │ │
│  │  2. Download .json.gz files                                   │ │
│  │  3. Decompress and parse JSON                                 │ │
│  │  4. Extract fields:                                            │ │
│  │     • timestamp, event_name, event_source                     │ │
│  │     • user_type, principal_id, arn                            │ │
│  │     • access_key_id, source_ip                                │ │
│  │     • aws_region, resources                                   │ │
│  │     • error_code, error_message                               │ │
│  │     • success (true/false)                                    │ │
│  │  5. Write formatted JSON lines to:                            │ │
│  │     /var/log/cloudtrail-processed/cloudtrail_TIMESTAMP.log    │ │
│  │  6. Track state to avoid reprocessing                         │ │
│  │  7. Cleanup old files (retention: 7 days)                     │ │
│  └───────────────────────────┬───────────────────────────────────┘ │
│                              │                                      │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Local Log Files                                              │ │
│  │  /var/log/cloudtrail-processed/                               │ │
│  │  ├─ cloudtrail_20260203_120000.log                            │ │
│  │  ├─ cloudtrail_20260203_120500.log                            │ │
│  │  └─ cloudtrail_20260203_121000.log                            │ │
│  │                                                                │ │
│  │  Format: JSON lines (one event per line)                      │ │
│  │  Example:                                                      │ │
│  │  {"timestamp":"2026-02-03T12:00:00Z",                         │ │
│  │   "event_name":"ConsoleLogin",                                │ │
│  │   "access_key_id":"AKIAIOSFODNN7EXAMPLE",                     │ │
│  │   "principal_id":"john.doe",                                  │ │
│  │   "source_ip":"203.0.113.1",                                  │ │
│  │   "success":"true"}                                           │ │
│  └───────────────────────────┬───────────────────────────────────┘ │
│                              │                                      │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Promtail (Log Shipper)                                       │ │
│  │  ────────────────────────────────────────────────────────────  │ │
│  │  1. Watches: /var/log/cloudtrail-processed/*.log             │ │
│  │  2. Reads new lines as they appear                            │ │
│  │  3. Parses JSON fields                                        │ │
│  │  4. Adds labels:                                              │ │
│  │     • job="cloudtrail"                                        │ │
│  │     • event_name, event_source                                │ │
│  │     • user_type, access_key_id                                │ │
│  │     • aws_region, success, error_code                         │ │
│  │  5. Formats log line for display                              │ │
│  │  6. Pushes to Loki via HTTP                                   │ │
│  └───────────────────────────┬───────────────────────────────────┘ │
│                              │                                      │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                               │ Protocol: HTTP
                               │ Port: 3100
                               │ Endpoint: /loki/api/v1/push
                               │ Format: Protobuf/JSON
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  EC2 #2: Monitoring Server (t3.medium)                             │
│  Private IP: 10.0.1.20                                              │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Loki (Log Aggregation)                                       │ │
│  │  Port: 3100                                                    │ │
│  │  ────────────────────────────────────────────────────────────  │ │
│  │  1. Receives logs from Promtail                               │ │
│  │  2. Indexes by labels (not full-text)                         │ │
│  │  3. Stores in chunks (compressed)                             │ │
│  │  4. Provides query API for Grafana                            │ │
│  │  5. Retention: 30 days (configurable)                         │ │
│  │                                                                │ │
│  │  Storage Structure:                                            │ │
│  │  /var/lib/loki/                                                │ │
│  │  ├─ chunks/     (compressed log data)                         │ │
│  │  └─ index/      (label index)                                 │ │
│  └───────────────────────────┬───────────────────────────────────┘ │
│                              │                                      │
│                              │ Internal API                         │
│                              │                                      │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Grafana (Visualization)                                      │ │
│  │  Port: 3000                                                    │ │
│  │  ────────────────────────────────────────────────────────────  │ │
│  │  1. Queries Loki using LogQL                                  │ │
│  │  2. Displays dashboards:                                      │ │
│  │     • Event timeline                                          │ │
│  │     • Access key usage                                        │ │
│  │     • Failed events                                           │ │
│  │     • User activity                                           │ │
│  │     • Regional distribution                                   │ │
│  │  3. Triggers alerts based on rules                            │ │
│  │  4. Sends notifications (Slack/Email)                         │ │
│  │  5. Provides search and filtering                             │ │
│  └───────────────────────────┬───────────────────────────────────┘ │
│                              │                                      │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                               │ HTTPS (443)
                               │ Web Interface
                               │
                               ▼
                        ┌──────────────┐
                        │    Users     │
                        │  (Browser)   │
                        └──────────────┘
```

---

## Data Flow Example

### Scenario: User logs into AWS Console

```
Step 1: AWS CloudTrail
─────────────────────────────────────────────────────────────
Event occurs: User "john.doe" logs into AWS Console
CloudTrail creates log entry:
{
  "eventTime": "2026-02-03T12:00:00Z",
  "eventName": "ConsoleLogin",
  "userIdentity": {
    "type": "IAMUser",
    "principalId": "AIDAI23HXS4EXAMPLE",
    "arn": "arn:aws:iam::123456789012:user/john.doe",
    "accessKeyId": "AKIAIOSFODNN7EXAMPLE"
  },
  "sourceIPAddress": "203.0.113.1",
  "awsRegion": "us-east-1",
  "responseElements": {"ConsoleLogin": "Success"}
}

Step 2: S3 Storage
─────────────────────────────────────────────────────────────
CloudTrail writes to S3:
s3://my-cloudtrail-bucket/AWSLogs/123456789012/CloudTrail/
  us-east-1/2026/02/03/
  123456789012_CloudTrail_us-east-1_20260203T1200Z_abc123.json.gz

Step 3: Python Script (Every 5 minutes)
─────────────────────────────────────────────────────────────
1. Lists S3 bucket for new files
2. Downloads: 123456789012_CloudTrail_us-east-1_20260203T1200Z_abc123.json.gz
3. Decompresses gzip
4. Parses JSON
5. Extracts and formats:
   {
     "timestamp": "2026-02-03T12:00:00Z",
     "event_name": "ConsoleLogin",
     "event_source": "signin.amazonaws.com",
     "user_type": "IAMUser",
     "principal_id": "AIDAI23HXS4EXAMPLE",
     "arn": "arn:aws:iam::123456789012:user/john.doe",
     "access_key_id": "AKIAIOSFODNN7EXAMPLE",
     "source_ip": "203.0.113.1",
     "aws_region": "us-east-1",
     "success": "true",
     "error_code": "",
     "error_message": ""
   }
6. Writes to: /var/log/cloudtrail-processed/cloudtrail_20260203_120500.log

Step 4: Promtail (Real-time)
─────────────────────────────────────────────────────────────
1. Detects new line in log file
2. Parses JSON
3. Adds labels:
   - job="cloudtrail"
   - event_name="ConsoleLogin"
   - access_key_id="AKIAIOSFODNN7EXAMPLE"
   - user_type="IAMUser"
   - aws_region="us-east-1"
   - success="true"
4. Formats display line:
   "ConsoleLogin by AIDAI23HXS4EXAMPLE (AKIAIOSFODNN7EXAMPLE) 
    from 203.0.113.1 - Success: true"
5. Pushes to Loki at http://10.0.1.20:3100/loki/api/v1/push

Step 5: Loki (Real-time)
─────────────────────────────────────────────────────────────
1. Receives log entry
2. Indexes by labels (not content)
3. Compresses and stores
4. Makes available for querying

Step 6: Grafana (Real-time)
─────────────────────────────────────────────────────────────
1. Dashboard auto-refreshes (30s interval)
2. Queries Loki: {job="cloudtrail"}
3. Displays in panels:
   - Timeline: Shows spike at 12:00
   - Access Key chart: Shows AKIAIOSFODNN7EXAMPLE activity
   - Recent Events table: Shows login event
   - User Type chart: Increments IAMUser count

Step 7: Alert Evaluation (Every 1 minute)
─────────────────────────────────────────────────────────────
Grafana checks alert rules:
- "Multiple Failed Logins": No match (success=true)
- "Root Account Usage": No match (user_type=IAMUser)
- No alerts triggered

Step 8: User Views in Grafana
─────────────────────────────────────────────────────────────
User opens Grafana dashboard and sees:
- Event appeared in timeline at 12:00
- Can filter by access_key_id="AKIAIOSFODNN7EXAMPLE"
- Can see all actions by this user
- Can drill down to see full details
```

---

## Component Responsibilities

### CloudTrail
- ✅ Captures all AWS API calls
- ✅ Records metadata (who, what, when, where)
- ✅ Writes to S3 in near real-time (5-15 minutes)
- ✅ Handles log file validation

### S3 Bucket
- ✅ Stores CloudTrail logs durably
- ✅ Organizes by account/region/date
- ✅ Provides access via IAM policies
- ✅ Encrypts data at rest

### Python Script (cloudtrail_processor.py)
- ✅ Downloads new logs from S3
- ✅ Parses compressed JSON files
- ✅ Extracts relevant fields
- ✅ Formats for Promtail consumption
- ✅ Tracks processing state
- ✅ Manages log retention

### Promtail
- ✅ Tails log files
- ✅ Parses JSON format
- ✅ Adds labels for filtering
- ✅ Pushes to Loki
- ✅ Handles retries and backpressure

### Loki
- ✅ Receives logs from Promtail
- ✅ Indexes by labels (efficient)
- ✅ Stores compressed chunks
- ✅ Provides query API
- ✅ Manages retention

### Grafana
- ✅ Queries Loki with LogQL
- ✅ Visualizes data in dashboards
- ✅ Evaluates alert rules
- ✅ Sends notifications
- ✅ Provides user interface

---

## Network Flow

```
┌─────────────┐                    ┌─────────────┐
│   EC2 #1    │                    │   EC2 #2    │
│  10.0.1.10  │                    │  10.0.1.20  │
└─────────────┘                    └─────────────┘
      │                                   │
      │ Outbound: HTTPS (443)            │
      ├──────────────────────────────────┤
      │         to AWS S3                │
      │                                   │
      │ Outbound: HTTP (3100)            │
      ├──────────────────────────────────┤
      │         to Loki                  │
      │                                   │
      │                            Inbound: HTTP (3100)
      │                            from Promtail
      │                                   │
      │                            Inbound: HTTPS (443)
      │                            from User Browser
      │                            to Grafana (3000)
```

---

## Timing & Latency

```
Event occurs in AWS
    ↓
    │ 5-15 minutes (CloudTrail delay)
    ↓
Log written to S3
    ↓
    │ 0-5 minutes (script interval)
    ↓
Script downloads log
    ↓
    │ < 1 second (processing)
    ↓
Formatted log written
    ↓
    │ < 1 second (Promtail tailing)
    ↓
Promtail pushes to Loki
    ↓
    │ < 1 second (network + indexing)
    ↓
Available in Loki
    ↓
    │ 0-30 seconds (dashboard refresh)
    ↓
Visible in Grafana

Total latency: 5-20 minutes (mostly CloudTrail delay)
```

---

## Security Boundaries

```
┌──────────────────────────────────────────────────────┐
│  AWS Account Boundary                                │
│                                                      │
│  ┌────────────┐         ┌────────────┐             │
│  │ CloudTrail │────────▶│ S3 Bucket  │             │
│  └────────────┘         └────────────┘             │
│                              │                       │
│                              │ IAM Role              │
│                              │ (Read Only)           │
└──────────────────────────────┼───────────────────────┘
                               │
                               │ HTTPS (TLS 1.2+)
                               │ Encrypted in transit
                               │
┌──────────────────────────────┼───────────────────────┐
│  VPC (10.0.0.0/16)          │                       │
│                              │                       │
│  ┌───────────────────────────┼─────────────────────┐ │
│  │ Private Subnet 1          │                     │ │
│  │ (10.0.1.0/24)             ▼                     │ │
│  │                    ┌─────────────┐              │ │
│  │                    │   EC2 #1    │              │ │
│  │                    │  Processor  │              │ │
│  │                    └─────────────┘              │ │
│  │                           │                     │ │
│  └───────────────────────────┼─────────────────────┘ │
│                              │                       │
│                              │ Internal Network      │
│                              │ (Private IPs)         │
│                              │                       │
│  ┌───────────────────────────┼─────────────────────┐ │
│  │ Private Subnet 2          │                     │ │
│  │ (10.0.2.0/24)             ▼                     │ │
│  │                    ┌─────────────┐              │ │
│  │                    │   EC2 #2    │              │ │
│  │                    │ Monitoring  │              │ │
│  │                    └─────────────┘              │ │
│  │                           │                     │ │
│  └───────────────────────────┼─────────────────────┘ │
│                              │                       │
└──────────────────────────────┼───────────────────────┘
                               │
                               │ HTTPS (TLS 1.2+)
                               │ via Load Balancer
                               │
                        ┌──────┴──────┐
                        │    Users    │
                        │  (Browser)  │
                        └─────────────┘
```

---

## Scalability Considerations

### Current Setup (Small Scale)
- **CloudTrail Events**: < 10,000/day
- **EC2 #1**: t3.small (2 vCPU, 2 GB RAM)
- **EC2 #2**: t3.medium (2 vCPU, 4 GB RAM)
- **Processing**: Every 5 minutes
- **Cost**: ~$30-50/month

### Medium Scale (10,000-100,000 events/day)
- **EC2 #1**: t3.medium
- **EC2 #2**: t3.large
- **Processing**: Every 2 minutes
- **Add**: Loki compactor for better performance
- **Cost**: ~$100-150/month

### Large Scale (100,000+ events/day)
- **EC2 #1**: c5.large (dedicated compute)
- **EC2 #2**: r5.xlarge (more memory for Loki)
- **Processing**: Every 1 minute or real-time with Lambda
- **Add**: Loki distributed mode (multiple instances)
- **Add**: S3 backend for Loki storage
- **Cost**: ~$300-500/month

---

## High Availability Setup (Optional)

```
                    ┌─────────────┐
                    │ CloudTrail  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  S3 Bucket  │
                    └──────┬──────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
     ┌──────▼──────┐             ┌───────▼──────┐
     │  EC2 #1a    │             │  EC2 #1b     │
     │ Processor   │             │  Processor   │
     │ (Primary)   │             │  (Standby)   │
     └──────┬──────┘             └───────┬──────┘
            │                             │
            └──────────────┬──────────────┘
                           │
                    ┌──────▼──────┐
                    │     ALB     │
                    └──────┬──────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
     ┌──────▼──────┐             ┌───────▼──────┐
     │  Loki #1    │◄───────────▶│  Loki #2     │
     │ (Primary)   │  Replication │  (Replica)   │
     └──────┬──────┘             └───────┬──────┘
            │                             │
            └──────────────┬──────────────┘
                           │
                    ┌──────▼──────┐
                    │  Grafana    │
                    │  (Cluster)  │
                    └─────────────┘
```

This is for production environments with strict uptime requirements.
