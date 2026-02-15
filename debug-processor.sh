#!/bin/bash
# Debug CloudTrail Processor Output
# Run this on EC2 instance

echo "🔍 CloudTrail Processor Debug"
echo "=============================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Find config file
echo "1️⃣ Looking for config.yaml..."
CONFIG_FILES=$(find ~ /home /opt /etc -name "config.yaml" -type f 2>/dev/null | grep -i cloudtrail)

if [ -n "$CONFIG_FILES" ]; then
    echo -e "${GREEN}✅ Found config file(s):${NC}"
    echo "$CONFIG_FILES"
    echo ""
    
    # Show content of each config
    for CONFIG in $CONFIG_FILES; do
        echo "📄 Content of $CONFIG:"
        echo "---"
        cat "$CONFIG"
        echo "---"
        echo ""
    done
else
    echo -e "${RED}❌ No config.yaml found${NC}"
    echo "Searching in common locations..."
    find / -name "config.yaml" -type f 2>/dev/null | head -5
fi
echo ""

# 2. Check service file
echo "2️⃣ Checking CloudTrail Processor service..."
if systemctl list-unit-files | grep -q cloudtrail-processor; then
    echo -e "${GREEN}✅ Service exists${NC}"
    echo ""
    echo "Service file content:"
    sudo systemctl cat cloudtrail-processor
    echo ""
else
    echo -e "${RED}❌ Service not found${NC}"
fi
echo ""

# 3. Check recent logs
echo "3️⃣ Recent CloudTrail Processor logs:"
echo "---"
sudo journalctl -u cloudtrail-processor -n 30 --no-pager
echo "---"
echo ""

# 4. Find any cloudtrail JSON files
echo "4️⃣ Searching for CloudTrail JSON files..."
echo "This may take a minute..."
FOUND_FILES=$(find /var /home /opt -name "cloudtrail*.json" -type f 2>/dev/null | head -10)

if [ -n "$FOUND_FILES" ]; then
    echo -e "${GREEN}✅ Found CloudTrail JSON files:${NC}"
    echo "$FOUND_FILES"
    echo ""
    
    # Show details of first file
    FIRST_FILE=$(echo "$FOUND_FILES" | head -1)
    echo "Details of $FIRST_FILE:"
    ls -lh "$FIRST_FILE"
    echo ""
    echo "Sample content:"
    tail -1 "$FIRST_FILE" | jq '.' 2>/dev/null || tail -1 "$FIRST_FILE"
else
    echo -e "${RED}❌ No CloudTrail JSON files found${NC}"
fi
echo ""

# 5. Check /var/log/cloudtrail/
echo "5️⃣ Checking /var/log/cloudtrail/..."
if [ -d "/var/log/cloudtrail" ]; then
    echo -e "${GREEN}✅ Directory exists${NC}"
    ls -lah /var/log/cloudtrail/
    
    # Check permissions
    echo ""
    echo "Permissions:"
    stat /var/log/cloudtrail/
else
    echo -e "${RED}❌ Directory does not exist${NC}"
fi
echo ""

# 6. Check Python script
echo "6️⃣ Looking for cloudtrail_processor.py..."
PROCESSOR_SCRIPT=$(find ~ /home /opt -name "cloudtrail_processor.py" -type f 2>/dev/null | head -1)

if [ -n "$PROCESSOR_SCRIPT" ]; then
    echo -e "${GREEN}✅ Found: $PROCESSOR_SCRIPT${NC}"
    
    # Check if it has output_file or log_directory
    echo ""
    echo "Checking for output configuration in script..."
    grep -n "output_file\|log_directory\|LOG_DIR" "$PROCESSOR_SCRIPT" | head -10
else
    echo -e "${RED}❌ cloudtrail_processor.py not found${NC}"
fi
echo ""

# 7. Summary
echo "=============================="
echo "📊 Summary & Recommendations"
echo "=============================="
echo ""

if [ -n "$CONFIG_FILES" ]; then
    echo "✅ Config file found. Check the 'output_file' or 'log_directory' setting."
    echo "   It should be: /var/log/cloudtrail/cloudtrail.json"
else
    echo "❌ Config file not found. The processor might be using hardcoded paths."
fi
echo ""

if [ -n "$FOUND_FILES" ]; then
    FIRST_DIR=$(dirname "$(echo "$FOUND_FILES" | head -1)")
    echo "✅ CloudTrail logs are being written to: $FIRST_DIR"
    echo "   You can either:"
    echo "   1. Move files: sudo mv $FIRST_DIR/cloudtrail*.json /var/log/cloudtrail/"
    echo "   2. Update Promtail config to read from: $FIRST_DIR/*.json"
else
    echo "❌ No CloudTrail JSON files found anywhere."
    echo "   Check CloudTrail Processor logs for errors."
fi
echo ""

echo "Next steps:"
echo "1. Update config.yaml with correct output_file path"
echo "2. Restart: sudo systemctl restart cloudtrail-processor"
echo "3. Wait 30 seconds and check: ls -lh /var/log/cloudtrail/"
