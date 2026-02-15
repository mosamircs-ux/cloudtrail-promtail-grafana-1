#!/bin/bash
# Quick Fix Script for CloudTrail Dashboard
# Run this on the EC2 instance

echo "🚀 CloudTrail Dashboard Quick Fix"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Create log directory
echo "1️⃣ Creating log directory..."
sudo mkdir -p /var/log/cloudtrail
sudo chmod 755 /var/log/cloudtrail
echo -e "${GREEN}✅ Created /var/log/cloudtrail${NC}"
echo ""

# 2. Find and update CloudTrail Processor config
echo "2️⃣ Looking for CloudTrail Processor config..."
CONFIG_FILE=$(find ~ -name "config.yaml" -type f 2>/dev/null | grep cloudtrail | head -1)

if [ -n "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✅ Found config: $CONFIG_FILE${NC}"
    echo "   Backing up..."
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
    
    echo "   Please update the output_file path to:"
    echo "   output_file: /var/log/cloudtrail/cloudtrail.json"
    echo ""
    echo "   Opening editor in 5 seconds..."
    sleep 5
    nano "$CONFIG_FILE"
else
    echo -e "${YELLOW}⚠️  Config file not found. Please locate it manually.${NC}"
fi
echo ""

# 3. Create Promtail config
echo "3️⃣ Creating Promtail config..."
sudo mkdir -p /etc/promtail

# Ask for Loki URL
echo "Enter your Loki server URL (e.g., http://localhost:3100 or http://YOUR_LOKI_IP:3100):"
read LOKI_URL

sudo tee /etc/promtail/promtail-cloudtrail-config.yml > /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: ${LOKI_URL}/loki/api/v1/push

scrape_configs:
  - job_name: cloudtrail
    static_configs:
      - targets:
          - localhost
        labels:
          job: cloudtrail
          __path__: /var/log/cloudtrail/*.json

    pipeline_stages:
      - json:
          expressions:
            timestamp: timestamp
            event_name: event_name
            event_source: event_source
            access_key_id: access_key_id
            success: success
            aws_region: aws_region
            resources: resources
            principal_id: principal_id
            source_ip: source_ip
            error_code: error_code
            error_message: error_message
      
      - labels:
          event_name:
          event_source:
          access_key_id:
          success:
          aws_region:
      
      - timestamp:
          source: timestamp
          format: RFC3339
EOF

echo -e "${GREEN}✅ Created Promtail config${NC}"
echo ""

# 4. Restart services
echo "4️⃣ Restarting services..."
sudo systemctl restart cloudtrail-processor
echo -e "${GREEN}✅ Restarted CloudTrail Processor${NC}"

sudo systemctl restart promtail
echo -e "${GREEN}✅ Restarted Promtail${NC}"
echo ""

# 5. Wait and check
echo "5️⃣ Waiting 30 seconds for logs to be generated..."
sleep 30
echo ""

# 6. Check logs
echo "6️⃣ Checking log files..."
if [ -f /var/log/cloudtrail/cloudtrail-*.json ]; then
    echo -e "${GREEN}✅ Log files found!${NC}"
    ls -lh /var/log/cloudtrail/
    echo ""
    echo "Sample log entry:"
    tail -1 /var/log/cloudtrail/cloudtrail-*.json | jq '.' 2>/dev/null || tail -1 /var/log/cloudtrail/cloudtrail-*.json
else
    echo -e "${RED}❌ No log files yet. Check CloudTrail Processor logs:${NC}"
    echo "   sudo journalctl -u cloudtrail-processor -n 50"
fi
echo ""

# 7. Check Promtail
echo "7️⃣ Checking Promtail..."
sleep 10
if sudo journalctl -u promtail -n 20 | grep -q "Successfully sent batch"; then
    echo -e "${GREEN}✅ Promtail is sending logs to Loki!${NC}"
else
    echo -e "${YELLOW}⚠️  Promtail not sending yet. Check logs:${NC}"
    echo "   sudo journalctl -u promtail -f"
fi
echo ""

# 8. Summary
echo "=================================="
echo "📊 Summary"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Go to Grafana → Explore"
echo "2. Select Loki data source"
echo "3. Query: {job=\"cloudtrail\"}"
echo "4. You should see logs now!"
echo "5. Refresh your dashboard"
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
