# Quick Reference - Access Key & Resource Tracking Queries

## 🚀 Most Used Queries

### 1. كل نشاط Access Key معين
```logql
{job="cloudtrail", access_key_id="AKIA..."}
```

### 2. مين وصل لـ Resource معين
```logql
{job="cloudtrail"} |~ "resource-id-or-arn"
```

### 3. استهلاك كل Access Key
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h]))
```

### 4. Failed Actions لكل Key
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="false"}[24h]))
```

### 5. Access Keys النشطة
```logql
topk(10, sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])))
```

---

## 🔍 Resource-Specific Queries

### EC2 Instance
```logql
# مين وصل لـ instance معين
{job="cloudtrail"} |~ "i-0123456789abcdef0"

# كل EC2 operations
{job="cloudtrail", event_name=~"RunInstances|StartInstances|StopInstances|TerminateInstances"}
```

### S3 Bucket
```logql
# مين وصل لـ bucket معين
{job="cloudtrail"} |~ "arn:aws:s3:::my-bucket"

# كل S3 operations
{job="cloudtrail", event_name=~"PutObject|GetObject|DeleteObject"}
```

### RDS Database
```logql
{job="cloudtrail", event_source="rds.amazonaws.com"}
```

### Lambda Function
```logql
{job="cloudtrail", event_source="lambda.amazonaws.com"}
```

---

## 🛡️ Security Queries

### Access Keys مشبوهة
```logql
# Keys بـ failed attempts كتير
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="false"}[1h])) > 10

# Keys من IPs كتير
count by (access_key_id) (
  count by (access_key_id, source_ip) (
    count_over_time({job="cloudtrail", access_key_id!="N/A"}[1h])
  )
) > 5

# Keys في regions كتير
count by (access_key_id) (
  count by (access_key_id, aws_region) (
    count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])
  )
) > 2
```

### Privilege Escalation
```logql
{job="cloudtrail", event_name=~"AttachUserPolicy|AttachRolePolicy|PutUserPolicy|PutRolePolicy"}
```

### New Access Keys Created
```logql
{job="cloudtrail", event_name="CreateAccessKey"}
```

---

## 📊 Statistics Queries

### Total Actions per Key
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range]))
```

### Unique Resources per Key
```logql
count by (access_key_id) (
  count by (access_key_id, event_name) (
    count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range])
  )
)
```

### Success Rate per Key
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="true"}[24h])) 
/ 
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])) * 100
```

---

## 🕐 Time-Based Queries

### Last 1 Hour
```logql
{job="cloudtrail", access_key_id!="N/A"} [1h]
```

### Last 24 Hours
```logql
{job="cloudtrail", access_key_id!="N/A"} [24h]
```

### Last 7 Days
```logql
{job="cloudtrail", access_key_id!="N/A"} [7d]
```

### Activity Timeline
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__interval]))
```

---

## 📋 Detailed Logs

### Complete Activity Log
```logql
{job="cloudtrail", access_key_id=~"$access_key"} 
| json 
| line_format "{{.timestamp}} | {{.access_key_id}} | {{.event_name}} | {{.resources}} | {{.success}}"
```

### Failed Operations Only
```logql
{job="cloudtrail", access_key_id!="N/A", success="false"} 
| json 
| line_format "{{.timestamp}} | {{.access_key_id}} | {{.event_name}} | {{.error_code}}: {{.error_message}}"
```

### With Source IP
```logql
{job="cloudtrail", access_key_id!="N/A"} 
| json 
| line_format "{{.timestamp}} | {{.access_key_id}} | {{.source_ip}} | {{.event_name}}"
```

---

## 🎯 Common Use Cases

### Case 1: Audit Access Key
```logql
# Step 1: Get all activity
{job="cloudtrail", access_key_id="AKIA..."}

# Step 2: Count by event
sum by (event_name) (count_over_time({job="cloudtrail", access_key_id="AKIA..."}[24h]))

# Step 3: Check failures
{job="cloudtrail", access_key_id="AKIA...", success="false"}
```

### Case 2: Find Who Accessed Resource
```logql
# Step 1: Find all access
{job="cloudtrail"} |~ "resource-id"

# Step 2: Group by access key
sum by (access_key_id, event_name) (count_over_time({job="cloudtrail"} |~ "resource-id" [24h]))

# Step 3: Get details
{job="cloudtrail"} |~ "resource-id" | json
```

### Case 3: Monitor EC2 Instance
```logql
# Step 1: All EC2 events for instance
{job="cloudtrail"} |~ "i-0123456789abcdef0"

# Step 2: Who did what
{job="cloudtrail"} |~ "i-0123456789abcdef0" 
| json 
| line_format "{{.timestamp}} | {{.access_key_id}} | {{.event_name}}"

# Step 3: Count by action
sum by (event_name) (count_over_time({job="cloudtrail"} |~ "i-0123456789abcdef0" [24h]))
```

---

## 💡 Pro Tips

### 1. Use Variables
```logql
# Instead of hardcoding
{job="cloudtrail", access_key_id="AKIA..."}

# Use variable
{job="cloudtrail", access_key_id=~"$access_key"}
```

### 2. Combine Filters
```logql
# Multiple conditions
{job="cloudtrail", access_key_id!="N/A", success="false", aws_region="us-east-1"}
```

### 3. Use Regex for Multiple Values
```logql
# Multiple event names
{job="cloudtrail", event_name=~"RunInstances|StartInstances|StopInstances"}

# Multiple regions
{job="cloudtrail", aws_region=~"us-east-1|us-west-2"}
```

### 4. Limit Results for Testing
```logql
{job="cloudtrail"} | limit 100
```

### 5. Use $__interval for Auto-Scaling
```logql
# Automatically adjusts based on time range
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__interval]))
```

---

## 🔧 Troubleshooting Queries

### Check if Data is Coming
```logql
{job="cloudtrail"} | limit 10
```

### Check Labels
```logql
{job="cloudtrail"} | json | line_format "{{.access_key_id}}"
```

### Count Events per Minute
```logql
sum(count_over_time({job="cloudtrail"}[1m]))
```

### Check Specific Field
```logql
{job="cloudtrail"} | json | line_format "{{.field_name}}"
```

---

## 📖 Query Syntax Reference

### Basic Structure
```logql
{label="value"} | filter | format
```

### Label Filters
```logql
{job="cloudtrail"}                          # Exact match
{access_key_id!="N/A"}                      # Not equal
{event_name=~"Run.*"}                       # Regex match
{event_name!~"Describe.*"}                  # Regex not match
```

### Line Filters
```logql
| json                                      # Parse JSON
| line_format "{{.field}}"                  # Format output
| regexp "pattern"                          # Regex filter
|~ "text"                                   # Contains
|!~ "text"                                  # Not contains
```

### Aggregations
```logql
sum by (label)                              # Sum grouped by label
count by (label)                            # Count grouped by label
topk(N, query)                              # Top N results
bottomk(N, query)                           # Bottom N results
```

### Time Functions
```logql
count_over_time({job="cloudtrail"}[5m])    # Count in 5 minutes
rate({job="cloudtrail"}[1m])               # Rate per second
sum_over_time({job="cloudtrail"}[1h])      # Sum over 1 hour
```

---

## 🎨 Panel Types & Best Queries

### Time Series Panel
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__interval]))
```

### Table Panel
```logql
{job="cloudtrail"} | json
```

### Gauge Panel
```logql
sum(count_over_time({job="cloudtrail"}[$__range]))
```

### Pie Chart Panel
```logql
sum by (event_name) (count_over_time({job="cloudtrail"}[$__range]))
```

---

## 📱 Quick Copy-Paste

### Dashboard Variables
```
Name: access_key
Query: label_values({job="cloudtrail"}, access_key_id)

Name: event_name
Query: label_values({job="cloudtrail"}, event_name)

Name: aws_region
Query: label_values({job="cloudtrail"}, aws_region)
```

### Common Time Ranges
- Last 5 minutes: `now-5m`
- Last 1 hour: `now-1h`
- Last 6 hours: `now-6h`
- Last 24 hours: `now-24h`
- Last 7 days: `now-7d`

---

**Keep this handy for quick reference! 🚀**
