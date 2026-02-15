# Grafana Query Examples for CloudTrail

## Basic Queries

### All CloudTrail Events
```logql
{job="cloudtrail"}
```

### Events in Last Hour
```logql
{job="cloudtrail"} |> timestamp >= now() - 1h
```

### Count All Events
```logql
sum(count_over_time({job="cloudtrail"}[1h]))
```

---

## Filter by Access Key

### Specific Access Key
```logql
{job="cloudtrail", access_key_id="AKIAIOSFODNN7EXAMPLE"}
```

### All Events with Access Keys (exclude N/A)
```logql
{job="cloudtrail", access_key_id!="N/A"}
```

### Count Events per Access Key
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h]))
```

### Top 10 Most Active Access Keys
```logql
topk(10, sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])))
```

---

## Filter by Event Name

### Console Login Events
```logql
{job="cloudtrail", event_name="ConsoleLogin"}
```

### EC2 Instance Actions
```logql
{job="cloudtrail", event_name=~"RunInstances|TerminateInstances|StopInstances|StartInstances"}
```

### S3 Operations
```logql
{job="cloudtrail", event_name=~"PutObject|GetObject|DeleteObject"}
```

### IAM Changes
```logql
{job="cloudtrail", event_name=~"CreateUser|DeleteUser|CreateRole|DeleteRole|AttachUserPolicy|DetachUserPolicy"}
```

### Security Group Changes
```logql
{job="cloudtrail", event_name=~"AuthorizeSecurityGroupIngress|RevokeSecurityGroupIngress"}
```

---

## Filter by User/Principal

### Root Account Activity
```logql
{job="cloudtrail", user_type="Root"}
```

### IAM User Activity
```logql
{job="cloudtrail", user_type="IAMUser"}
```

### Assumed Role Activity
```logql
{job="cloudtrail", user_type="AssumedRole"}
```

### Specific User ARN
```logql
{job="cloudtrail"} |~ "arn:aws:iam::123456789012:user/john"
```

---

## Filter by Success/Failure

### Failed Events Only
```logql
{job="cloudtrail", success="false"}
```

### Successful Events Only
```logql
{job="cloudtrail", success="true"}
```

### Failed Login Attempts
```logql
{job="cloudtrail", event_name="ConsoleLogin", success="false"}
```

### Count Failed Events
```logql
sum(count_over_time({job="cloudtrail", success="false"}[1h]))
```

---

## Filter by Error Code

### Access Denied Errors
```logql
{job="cloudtrail", error_code="AccessDenied"}
```

### All Errors (any error code)
```logql
{job="cloudtrail", error_code!=""}
```

### Count Errors by Type
```logql
sum by (error_code) (count_over_time({job="cloudtrail", error_code!=""}[24h]))
```

---

## Filter by AWS Region

### Specific Region
```logql
{job="cloudtrail", aws_region="us-east-1"}
```

### Multiple Regions
```logql
{job="cloudtrail", aws_region=~"us-east-1|us-west-2"}
```

### Events by Region (count)
```logql
sum by (aws_region) (count_over_time({job="cloudtrail"}[24h]))
```

---

## Filter by Source IP

### Specific IP Address
```logql
{job="cloudtrail"} |~ "203.0.113.1"
```

### IP Range (using regex)
```logql
{job="cloudtrail"} |~ "203\\.0\\.113\\."
```

### Events from AWS Services (internal IPs)
```logql
{job="cloudtrail", source_ip=~".*amazonaws.com"}
```

---

## Time-Based Queries

### Events in Last 5 Minutes
```logql
sum(count_over_time({job="cloudtrail"}[5m]))
```

### Events per Hour (rate)
```logql
sum(rate({job="cloudtrail"}[1h]))
```

### Events Timeline (5-minute intervals)
```logql
sum by (event_name) (count_over_time({job="cloudtrail"}[5m]))
```

---

## Advanced Queries

### Access Key Used from Multiple IPs
```logql
count by (access_key_id) (
  count by (access_key_id, source_ip) (
    count_over_time({job="cloudtrail", access_key_id!="N/A"}[1h])
  )
) > 3
```

### Most Active Users (by event count)
```logql
topk(10, sum by (principal_id) (count_over_time({job="cloudtrail"}[24h])))
```

### Failed Events by User
```logql
sum by (principal_id) (count_over_time({job="cloudtrail", success="false"}[24h]))
```

### Events Outside Business Hours (6 AM - 6 PM)
```logql
{job="cloudtrail"} 
| json 
| line_format "{{.timestamp}}" 
| regexp "(?P<hour>\\d{2}):\\d{2}:\\d{2}" 
| hour < "06" or hour > "18"
```

---

## Resource-Specific Queries

### S3 Bucket Access
```logql
{job="cloudtrail"} |~ "arn:aws:s3:::my-bucket"
```

### EC2 Instance Actions
```logql
{job="cloudtrail"} |~ "i-[a-z0-9]+" | event_name=~".*Instance.*"
```

### RDS Database Operations
```logql
{job="cloudtrail", event_source="rds.amazonaws.com"}
```

### Lambda Function Invocations
```logql
{job="cloudtrail", event_source="lambda.amazonaws.com"}
```

---

## Security Monitoring Queries

### Privilege Escalation Attempts
```logql
{job="cloudtrail", event_name=~"AttachUserPolicy|AttachRolePolicy|PutUserPolicy|PutRolePolicy"}
```

### Encryption Key Usage
```logql
{job="cloudtrail", event_source="kms.amazonaws.com"}
```

### Network Changes
```logql
{job="cloudtrail", event_name=~"CreateVpc|DeleteVpc|CreateSubnet|DeleteSubnet|CreateInternetGateway"}
```

### Data Exfiltration Indicators
```logql
{job="cloudtrail", event_name=~"GetObject|CopyObject"} 
| json 
| line_format "{{.request_parameters}}" 
| regexp "\"bucketName\":\"(?P<bucket>[^\"]+)\""
```

---

## Compliance Queries

### All Administrative Actions
```logql
{job="cloudtrail", event_name=~"Create.*|Delete.*|Put.*|Attach.*|Detach.*"}
```

### Audit Trail for Specific Resource
```logql
{job="cloudtrail"} |~ "arn:aws:s3:::sensitive-data-bucket"
```

### Changes to Critical Resources
```logql
{job="cloudtrail", event_name=~"DeleteBucket|DeleteTable|DeleteDBInstance"}
```

---

## Performance Queries

### API Call Rate (calls per second)
```logql
sum(rate({job="cloudtrail"}[1m]))
```

### Slowest API Calls (if duration available)
```logql
{job="cloudtrail"} 
| json 
| line_format "{{.event_name}}: {{.duration}}"
```

### Most Called APIs
```logql
topk(20, sum by (event_name) (count_over_time({job="cloudtrail"}[24h])))
```

---

## Aggregation Queries

### Events by Event Source
```logql
sum by (event_source) (count_over_time({job="cloudtrail"}[24h]))
```

### Success Rate
```logql
sum(count_over_time({job="cloudtrail", success="true"}[1h])) 
/ 
sum(count_over_time({job="cloudtrail"}[1h])) * 100
```

### Error Rate
```logql
sum(count_over_time({job="cloudtrail", success="false"}[1h])) 
/ 
sum(count_over_time({job="cloudtrail"}[1h])) * 100
```

---

## User Activity Tracking

### All Actions by Specific User
```logql
{job="cloudtrail", principal_id=~".*john.doe.*"}
```

### User Login History
```logql
{job="cloudtrail", event_name="ConsoleLogin"} 
| json 
| line_format "{{.timestamp}} - {{.principal_id}} from {{.source_ip}}"
```

### User's Failed Actions
```logql
{job="cloudtrail", principal_id=~".*john.doe.*", success="false"}
```

---

## Access Key Monitoring

### New Access Key Creation
```logql
{job="cloudtrail", event_name="CreateAccessKey"}
```

### Access Key Deletion
```logql
{job="cloudtrail", event_name="DeleteAccessKey"}
```

### Access Key Usage Timeline
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[5m]))
```

### Inactive Access Keys (no activity in 24h)
```logql
# Run this in Grafana Explore to find all access keys
# Then compare with recent activity
count by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])) == 0
```

---

## JSON Parsing Examples

### Extract Request Parameters
```logql
{job="cloudtrail"} 
| json 
| line_format "Event: {{.event_name}}, Params: {{.request_parameters}}"
```

### Extract Specific Field
```logql
{job="cloudtrail"} 
| json timestamp, event_name, principal_id, source_ip
| line_format "{{.timestamp}} | {{.event_name}} | {{.principal_id}} | {{.source_ip}}"
```

### Filter by Nested JSON Field
```logql
{job="cloudtrail"} 
| json 
| request_parameters =~ ".*instanceType.*t3.large.*"
```

---

## Dashboard Panel Queries

### Gauge: Total Events Today
```logql
sum(count_over_time({job="cloudtrail"}[24h]))
```

### Gauge: Failed Events Today
```logql
sum(count_over_time({job="cloudtrail", success="false"}[24h]))
```

### Time Series: Events Over Time
```logql
sum by (event_name) (count_over_time({job="cloudtrail"}[$__interval]))
```

### Pie Chart: Events by Service
```logql
sum by (event_source) (count_over_time({job="cloudtrail"}[$__range]))
```

### Table: Recent Events
```logql
{job="cloudtrail"} 
| json 
| line_format "{{.timestamp}} | {{.event_name}} | {{.principal_id}} | {{.source_ip}} | {{.success}}"
```

### Bar Chart: Top Users
```logql
topk(10, sum by (principal_id) (count_over_time({job="cloudtrail"}[$__range])))
```

---

## Troubleshooting Queries

### Check Data Ingestion
```logql
{job="cloudtrail"} | limit 10
```

### Count Events per Minute
```logql
sum(count_over_time({job="cloudtrail"}[1m]))
```

### Check Label Values
```logql
# In Grafana Explore, use Label Browser to see all available labels
```

### Verify Timestamp Parsing
```logql
{job="cloudtrail"} 
| json timestamp
| line_format "{{.timestamp}}"
```

---

## Tips for Writing Queries

1. **Start Simple**: Begin with `{job="cloudtrail"}` and add filters
2. **Use Label Filters**: Faster than regex on log content
3. **Limit Results**: Use `| limit 100` for testing
4. **Use Variables**: In dashboards, use `$access_key`, `$region`, etc.
5. **Aggregate Wisely**: Use `sum by ()` to group results
6. **Time Ranges**: Use `$__interval` and `$__range` in dashboards

---

## Common Patterns

### Pattern: Find and Count
```logql
# Find specific events
{job="cloudtrail", event_name="DeleteBucket"}

# Count them
sum(count_over_time({job="cloudtrail", event_name="DeleteBucket"}[24h]))
```

### Pattern: Filter and Format
```logql
{job="cloudtrail", success="false"} 
| json 
| line_format "{{.event_name}} failed: {{.error_message}}"
```

### Pattern: Aggregate by Multiple Labels
```logql
sum by (event_name, aws_region) (count_over_time({job="cloudtrail"}[1h]))
```

---

## Save These as Grafana Saved Queries

In Grafana, you can save frequently used queries:
1. Go to **Explore**
2. Enter your query
3. Click **Add to dashboard** or save as a bookmark

This makes it easy to reuse complex queries!

---

## Access Key and Resource Tracking

### Access Key → Resources (What Each Key Accesses)
```logql
# Show all resources accessed by each access key
sum by (access_key_id, event_name) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range]))
```

### Resource → Access Keys (Who Has Access)
```logql
# Show which access keys accessed specific resources
{job="cloudtrail"} | json | line_format "{{.event_name}}|||{{.access_key_id}}|||{{.resources}}"
```

### Access Key Activity Timeline
```logql
# Timeline showing usage of each access key over time
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__interval]))
```

### Access Key Consumption Summary
```logql
# Total actions per access key
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range]))

# Failed actions per access key
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="false"}[$__range]))

# Unique resources accessed per access key
count by (access_key_id) (count by (access_key_id, event_name) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range])))
```

### Detailed Activity Log (Who Did What, When, Where)
```logql
# Complete activity log with all details
{job="cloudtrail", access_key_id=~"$access_key"} 
| json 
| line_format "{{.timestamp}} | {{.access_key_id}} | {{.event_name}} | {{.resources}} | {{.principal_id}} | {{.source_ip}} | {{.aws_region}} | {{.success}}"
```

### EC2 Instance Access Audit
```logql
# Show which access keys accessed EC2 instances
{job="cloudtrail", event_name=~"RunInstances|StartInstances|StopInstances|TerminateInstances|CreateVolume|DeleteVolume"} 
| json 
| line_format "{{.resources}}|||{{.access_key_id}}|||{{.event_name}}"
```

### S3 Bucket Access Audit
```logql
# Show which access keys accessed S3 buckets
{job="cloudtrail", event_name=~"PutObject|GetObject|DeleteObject|CreateBucket|DeleteBucket"} 
| json 
| line_format "{{.resources}}|||{{.access_key_id}}|||{{.event_name}}"
```

### Specific Access Key Activity
```logql
# All actions by a specific access key
{job="cloudtrail", access_key_id="AKIAIOSFODNN7EXAMPLE"}
```

### Access Key Resource Usage Count
```logql
# Count how many different resources each key accessed
count by (access_key_id) (
  count by (access_key_id, resources) (
    {job="cloudtrail", access_key_id!="N/A"} | json
  )
)
```

### Most Active Access Keys (by resource count)
```logql
# Top 10 access keys by number of different resources accessed
topk(10, 
  count by (access_key_id) (
    count by (access_key_id, event_name) (
      count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])
    )
  )
)
```

### Access Key Usage by Time of Day
```logql
# Access key activity grouped by hour
{job="cloudtrail", access_key_id!="N/A"} 
| json 
| line_format "{{.timestamp}}" 
| regexp "(?P<hour>\\d{2}):\\d{2}:\\d{2}"
```

### Suspicious Access Key Activity
```logql
# Access keys with high failure rates
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="false"}[1h])) 
> 10
```

### Access Key First and Last Seen
```logql
# First activity of each access key (use min_over_time)
min by (access_key_id) (timestamp({job="cloudtrail", access_key_id!="N/A"}))

# Last activity of each access key (use max_over_time)
max by (access_key_id) (timestamp({job="cloudtrail", access_key_id!="N/A"}))
```

### Resource Access Frequency
```logql
# How many times each resource was accessed
{job="cloudtrail"} 
| json 
| line_format "{{.resources}}"
```

### Access Keys Accessing Multiple Regions
```logql
# Access keys used in multiple AWS regions
count by (access_key_id) (
  count by (access_key_id, aws_region) (
    count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])
  )
) > 1
```

### Access Key Action Breakdown
```logql
# Breakdown of actions per access key
sum by (access_key_id, event_name) (
  count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])
)
```

---

## Resource-Specific Access Tracking

### EC2 Instance Access by ID
```logql
# Find who accessed a specific EC2 instance
{job="cloudtrail"} |~ "i-0123456789abcdef0"
```

### S3 Bucket Access by Name
```logql
# Find who accessed a specific S3 bucket
{job="cloudtrail"} |~ "arn:aws:s3:::my-bucket-name"
```

### RDS Database Access
```logql
# Find who accessed RDS databases
{job="cloudtrail", event_source="rds.amazonaws.com"} 
| json 
| line_format "{{.access_key_id}} | {{.event_name}} | {{.resources}}"
```

### Lambda Function Access
```logql
# Find who invoked Lambda functions
{job="cloudtrail", event_source="lambda.amazonaws.com"} 
| json 
| line_format "{{.access_key_id}} | {{.event_name}} | {{.resources}}"
```

### IAM Resource Changes
```logql
# Track IAM changes and who made them
{job="cloudtrail", event_name=~"CreateUser|DeleteUser|CreateRole|DeleteRole|AttachUserPolicy|DetachUserPolicy"} 
| json 
| line_format "{{.timestamp}} | {{.access_key_id}} | {{.event_name}} | {{.resources}}"
```

---

## Access Key Security Monitoring

### Unused Access Keys (No Activity)
```logql
# Find access keys with no activity in the time range
# (This requires comparing all known keys with active keys)
```

### Access Keys with Only Failed Attempts
```logql
# Access keys that only have failed attempts
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="true"}[24h])) == 0
and
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="false"}[24h])) > 0
```

### Access Keys from Unusual IPs
```logql
# Access keys used from multiple different IPs
count by (access_key_id) (
  count by (access_key_id, source_ip) (
    count_over_time({job="cloudtrail", access_key_id!="N/A"}[1h])
  )
) > 5
```

### Access Key Privilege Escalation Attempts
```logql
# Access keys attempting privilege escalation
{job="cloudtrail", access_key_id!="N/A", event_name=~"AttachUserPolicy|AttachRolePolicy|PutUserPolicy|PutRolePolicy"}
```

### Access Keys Creating New Keys
```logql
# Access keys that created new access keys
{job="cloudtrail", access_key_id!="N/A", event_name="CreateAccessKey"} 
| json 
| line_format "{{.access_key_id}} created new key at {{.timestamp}}"
```

---

## Dashboard Panel Recommendations

### Panel 1: Access Key → Resource Usage Table
- **Type**: Table
- **Query**: `sum by (access_key_id, event_name) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range]))`
- **Purpose**: Shows what each access key is accessing

### Panel 2: Resource → Access Keys Table
- **Type**: Table
- **Query**: `{job="cloudtrail"} | json | line_format "{{.event_name}}|||{{.access_key_id}}|||{{.resources}}"`
- **Purpose**: Shows which keys have access to each resource

### Panel 3: Access Key Activity Timeline
- **Type**: Time Series
- **Query**: `sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__interval]))`
- **Purpose**: Visualize access key usage over time

### Panel 4: Access Key Consumption Summary
- **Type**: Table with multiple queries
- **Queries**: 
  - Total Actions: `sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range]))`
  - Failed Actions: `sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="false"}[$__range]))`
  - Unique Resources: `count by (access_key_id) (count by (access_key_id, event_name) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range])))`
- **Purpose**: Complete statistics for each access key

### Panel 5: Detailed Activity Log
- **Type**: Table
- **Query**: `{job="cloudtrail", access_key_id=~"$access_key"} | json`
- **Purpose**: Complete audit trail with all details

### Panel 6: EC2 Access Audit
- **Type**: Table
- **Query**: `{job="cloudtrail", event_name=~"RunInstances|StartInstances|StopInstances|TerminateInstances"} | json`
- **Purpose**: Track EC2 instance access

### Panel 7: S3 Access Audit
- **Type**: Table
- **Query**: `{job="cloudtrail", event_name=~"PutObject|GetObject|DeleteObject"} | json`
- **Purpose**: Track S3 bucket access
