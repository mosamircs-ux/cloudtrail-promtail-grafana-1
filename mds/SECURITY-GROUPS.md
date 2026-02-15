# Security Groups Configuration

## Overview

Proper security group configuration is essential for the CloudTrail monitoring setup to work correctly while maintaining security.

---

## EC2 #1 (CloudTrail Processor) - Security Group

### Inbound Rules

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| SSH | TCP | 22 | Your IP | SSH access for management |

### Outbound Rules

| Type | Protocol | Port Range | Destination | Description |
|------|----------|------------|-------------|-------------|
| HTTPS | TCP | 443 | 0.0.0.0/0 | AWS S3 API access |
| Custom TCP | TCP | 3100 | EC2 #2 Security Group | Loki push endpoint |
| HTTP | TCP | 80 | 0.0.0.0/0 | Package updates (optional) |

---

## EC2 #2 (Monitoring - Grafana/Loki) - Security Group

### Inbound Rules

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| SSH | TCP | 22 | Your IP | SSH access for management |
| Custom TCP | TCP | 3000 | Your IP/VPN | Grafana web interface |
| Custom TCP | TCP | 3100 | EC2 #1 Security Group | Loki from Promtail |

### Outbound Rules

| Type | Protocol | Port Range | Destination | Description |
|------|----------|------------|-------------|-------------|
| All traffic | All | All | 0.0.0.0/0 | Allow all outbound |

---

## AWS CLI Configuration

### Create Security Group for EC2 #1

```bash
# Variables
VPC_ID="vpc-xxxxxxxxx"
EC2_2_SG_ID="sg-xxxxxxxxx"  # EC2 #2 security group ID
YOUR_IP="YOUR.IP.ADDRESS.HERE/32"

# Create security group
SG_1_ID=$(aws ec2 create-security-group \
  --group-name cloudtrail-processor-sg \
  --description "Security group for CloudTrail processor" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

echo "Created Security Group: $SG_1_ID"

# Add SSH access
aws ec2 authorize-security-group-ingress \
  --group-id $SG_1_ID \
  --protocol tcp \
  --port 22 \
  --cidr $YOUR_IP

# Add outbound HTTPS for S3
aws ec2 authorize-security-group-egress \
  --group-id $SG_1_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Add outbound to Loki
aws ec2 authorize-security-group-egress \
  --group-id $SG_1_ID \
  --protocol tcp \
  --port 3100 \
  --source-group $EC2_2_SG_ID

echo "Security Group $SG_1_ID configured"
```

### Update Security Group for EC2 #2

```bash
# Add inbound rule for Loki from EC2 #1
aws ec2 authorize-security-group-ingress \
  --group-id $EC2_2_SG_ID \
  --protocol tcp \
  --port 3100 \
  --source-group $SG_1_ID

echo "EC2 #2 Security Group updated to allow Loki traffic from EC2 #1"
```

---

## VPC Endpoint for S3 (Optional but Recommended)

Using a VPC endpoint for S3 eliminates internet traffic and reduces costs.

### Create S3 VPC Endpoint

```bash
# Get route table ID
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

# Create VPC endpoint
aws ec2 create-vpc-endpoint \
  --vpc-id $VPC_ID \
  --service-name com.amazonaws.REGION.s3 \
  --route-table-ids $ROUTE_TABLE_ID

echo "S3 VPC Endpoint created"
```

### Benefits:
- ✅ No internet gateway required
- ✅ No data transfer charges
- ✅ Better security (traffic stays in AWS network)
- ✅ Lower latency

---

## Network ACLs (Optional)

For additional security, configure Network ACLs:

### Subnet for EC2 #1

**Inbound**:
- Allow TCP 22 from your IP
- Allow TCP 1024-65535 from 0.0.0.0/0 (return traffic)

**Outbound**:
- Allow TCP 443 to 0.0.0.0/0 (S3 access)
- Allow TCP 3100 to EC2 #2 subnet
- Allow TCP 1024-65535 to 0.0.0.0/0 (return traffic)

---

## Verification

### Test Connectivity from EC2 #1

```bash
# Test S3 access
aws s3 ls s3://your-cloudtrail-bucket/

# Test Loki connectivity
curl http://EC2-2-PRIVATE-IP:3100/ready

# Test internet access (for updates)
curl -I https://www.google.com
```

### Test Connectivity from EC2 #2

```bash
# Test Loki is listening
sudo netstat -tlnp | grep 3100

# Test Grafana is accessible
curl http://localhost:3000
```

---

## Troubleshooting

### Cannot Connect to S3

1. **Check security group outbound rules**:
   ```bash
   aws ec2 describe-security-groups --group-ids $SG_1_ID
   ```

2. **Check VPC endpoint** (if using):
   ```bash
   aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID"
   ```

3. **Test S3 access**:
   ```bash
   aws s3 ls s3://your-bucket/ --debug
   ```

### Cannot Connect to Loki

1. **Check security group rules**:
   ```bash
   # On EC2 #2
   aws ec2 describe-security-groups --group-ids $EC2_2_SG_ID
   ```

2. **Check Loki is listening on all interfaces**:
   ```bash
   # On EC2 #2
   sudo netstat -tlnp | grep 3100
   # Should show: 0.0.0.0:3100 (not 127.0.0.1:3100)
   ```

3. **Test from EC2 #1**:
   ```bash
   # Get EC2 #2 private IP
   EC2_2_IP=$(aws ec2 describe-instances \
     --instance-ids i-xxxxxxxxx \
     --query 'Reservations[0].Instances[0].PrivateIpAddress' \
     --output text)
   
   # Test connection
   telnet $EC2_2_IP 3100
   curl http://$EC2_2_IP:3100/ready
   ```

### Promtail Cannot Push to Loki

1. **Check Promtail logs**:
   ```bash
   sudo journalctl -u promtail -n 100 | grep -i error
   ```

2. **Common errors**:
   - `connection refused`: Loki not running or wrong IP
   - `timeout`: Security group blocking traffic
   - `403 forbidden`: Authentication issue (not applicable for basic setup)

3. **Verify Promtail config**:
   ```bash
   cat /etc/promtail/promtail-config.yaml | grep url
   ```

---

## Security Best Practices

### 1. Principle of Least Privilege
- ✅ Only allow necessary ports
- ✅ Use security group references instead of CIDR blocks where possible
- ✅ Restrict SSH access to your IP only

### 2. Use Private IPs
- ✅ Use private IPs for EC2-to-EC2 communication
- ✅ Keep instances in private subnets if possible
- ✅ Use VPC endpoints for AWS services

### 3. Regular Audits
- ✅ Review security group rules monthly
- ✅ Remove unused rules
- ✅ Check for overly permissive rules (0.0.0.0/0)

### 4. Monitoring
- ✅ Enable VPC Flow Logs
- ✅ Monitor security group changes in CloudTrail
- ✅ Set up alerts for security group modifications

### 5. Encryption
- ✅ Use HTTPS for all API calls
- ✅ Enable encryption in transit for Loki (optional, for production)
- ✅ Ensure CloudTrail logs are encrypted at rest

---

## Production Recommendations

For production environments:

1. **Use Private Subnets**:
   - Place both EC2s in private subnets
   - Use NAT Gateway for internet access
   - Use VPC endpoints for AWS services

2. **Enable TLS for Loki**:
   - Configure Loki with TLS certificates
   - Update Promtail to use HTTPS

3. **Use AWS Systems Manager**:
   - Remove SSH access from security groups
   - Use SSM Session Manager for access

4. **Implement Network Segmentation**:
   - Separate subnets for different tiers
   - Use Network ACLs for additional security

5. **Enable Logging**:
   - VPC Flow Logs
   - CloudTrail for API calls
   - AWS Config for compliance

---

## Quick Reference

### Get Security Group ID

```bash
# By name
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=cloudtrail-processor-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text
```

### List All Rules

```bash
# Inbound
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions'

# Outbound
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```

### Remove a Rule

```bash
# Remove inbound rule
aws ec2 revoke-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```
