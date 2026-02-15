#!/bin/bash
# CloudTrail Dashboard Diagnostic Script
# اسم الملف: diagnose-dashboard.sh

echo "================================================"
echo "🔍 CloudTrail Dashboard Diagnostic Tool"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check CloudTrail Processor
echo "1️⃣ Checking CloudTrail Processor..."
if systemctl is-active --quiet cloudtrail-processor; then
    echo -e "${GREEN}✅ CloudTrail Processor is running${NC}"
else
    echo -e "${RED}❌ CloudTrail Processor is NOT running${NC}"
    echo "   Fix: sudo systemctl start cloudtrail-processor"
fi
echo ""

# 2. Check Promtail
echo "2️⃣ Checking Promtail..."
if systemctl is-active --quiet promtail; then
    echo -e "${GREEN}✅ Promtail is running${NC}"
else
    echo -e "${RED}❌ Promtail is NOT running${NC}"
    echo "   Fix: sudo systemctl start promtail"
fi
echo ""

# 3. Check Log Files
echo "3️⃣ Checking Log Files..."
LOG_DIR="/var/log/cloudtrail"
if [ -d "$LOG_DIR" ]; then
    LOG_COUNT=$(ls -1 $LOG_DIR/*.json 2>/dev/null | wc -l)
    if [ $LOG_COUNT -gt 0 ]; then
        echo -e "${GREEN}✅ Found $LOG_COUNT log file(s)${NC}"
        echo "   Latest file:"
        ls -lht $LOG_DIR/*.json | head -1
    else
        echo -e "${RED}❌ No log files found in $LOG_DIR${NC}"
        echo "   Check CloudTrail Processor logs: sudo journalctl -u cloudtrail-processor -n 50"
    fi
else
    echo -e "${RED}❌ Log directory $LOG_DIR does not exist${NC}"
    echo "   Create it: sudo mkdir -p $LOG_DIR"
fi
echo ""

# 4. Check Latest Logs
echo "4️⃣ Checking Latest Log Entries..."
LATEST_LOG=$(ls -t $LOG_DIR/*.json 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "   Latest log file: $LATEST_LOG"
    LAST_ENTRY=$(tail -1 "$LATEST_LOG")
    if [ -n "$LAST_ENTRY" ]; then
        echo -e "${GREEN}✅ Log file has data${NC}"
        echo "   Sample entry:"
        echo "$LAST_ENTRY" | jq '.' 2>/dev/null || echo "$LAST_ENTRY"
    else
        echo -e "${YELLOW}⚠️  Log file is empty${NC}"
    fi
else
    echo -e "${RED}❌ No log files found${NC}"
fi
echo ""

# 5. Check Promtail Config
echo "5️⃣ Checking Promtail Configuration..."
PROMTAIL_CONFIG="/etc/promtail/promtail-cloudtrail-config.yml"
if [ -f "$PROMTAIL_CONFIG" ]; then
    echo -e "${GREEN}✅ Promtail config exists${NC}"
    echo "   Checking for required labels..."
    
    if grep -q "job: cloudtrail" "$PROMTAIL_CONFIG"; then
        echo -e "${GREEN}   ✅ job: cloudtrail found${NC}"
    else
        echo -e "${RED}   ❌ job: cloudtrail NOT found${NC}"
    fi
    
    if grep -q "access_key_id" "$PROMTAIL_CONFIG"; then
        echo -e "${GREEN}   ✅ access_key_id label found${NC}"
    else
        echo -e "${YELLOW}   ⚠️  access_key_id label NOT found${NC}"
    fi
else
    echo -e "${RED}❌ Promtail config not found at $PROMTAIL_CONFIG${NC}"
fi
echo ""

# 6. Check Promtail Logs
echo "6️⃣ Checking Promtail Recent Activity..."
PROMTAIL_LOGS=$(sudo journalctl -u promtail -n 20 --no-pager 2>/dev/null)
if echo "$PROMTAIL_LOGS" | grep -q "Successfully sent batch"; then
    echo -e "${GREEN}✅ Promtail is sending logs to Loki${NC}"
    LAST_BATCH=$(echo "$PROMTAIL_LOGS" | grep "Successfully sent batch" | tail -1)
    echo "   $LAST_BATCH"
else
    echo -e "${RED}❌ No recent 'Successfully sent batch' messages${NC}"
    echo "   Check Promtail logs: sudo journalctl -u promtail -f"
fi
echo ""

# 7. Check CloudTrail Processor Logs
echo "7️⃣ Checking CloudTrail Processor Recent Activity..."
PROCESSOR_LOGS=$(sudo journalctl -u cloudtrail-processor -n 20 --no-pager 2>/dev/null)
if echo "$PROCESSOR_LOGS" | grep -q "Processing\|Downloaded\|Processed"; then
    echo -e "${GREEN}✅ CloudTrail Processor is processing files${NC}"
    LAST_PROCESS=$(echo "$PROCESSOR_LOGS" | grep -E "Processing|Downloaded|Processed" | tail -1)
    echo "   $LAST_PROCESS"
else
    echo -e "${YELLOW}⚠️  No recent processing activity${NC}"
    echo "   Check processor logs: sudo journalctl -u cloudtrail-processor -f"
fi
echo ""

# 8. Check Disk Space
echo "8️⃣ Checking Disk Space..."
DISK_USAGE=$(df -h $LOG_DIR 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
if [ -n "$DISK_USAGE" ]; then
    if [ $DISK_USAGE -lt 80 ]; then
        echo -e "${GREEN}✅ Disk space OK ($DISK_USAGE% used)${NC}"
    else
        echo -e "${YELLOW}⚠️  Disk space high ($DISK_USAGE% used)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not check disk space${NC}"
fi
echo ""

# 9. Summary
echo "================================================"
echo "📊 Summary"
echo "================================================"
echo ""

# Count issues
ISSUES=0

if ! systemctl is-active --quiet cloudtrail-processor; then
    ((ISSUES++))
fi

if ! systemctl is-active --quiet promtail; then
    ((ISSUES++))
fi

if [ ! -d "$LOG_DIR" ] || [ $(ls -1 $LOG_DIR/*.json 2>/dev/null | wc -l) -eq 0 ]; then
    ((ISSUES++))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "If dashboard still shows 'No data':"
    echo "1. Check Grafana data source configuration"
    echo "2. Verify Loki URL in Promtail config"
    echo "3. Check time range in Grafana (try Last 24h)"
    echo "4. Test in Grafana Explore: {job=\"cloudtrail\"}"
else
    echo -e "${RED}❌ Found $ISSUES issue(s)${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Fix the issues listed above"
    echo "2. Restart services: sudo systemctl restart cloudtrail-processor promtail"
    echo "3. Wait 2-3 minutes for data to flow"
    echo "4. Check Grafana dashboard again"
fi

echo ""
echo "================================================"
echo "📖 For detailed troubleshooting, see:"
echo "   TROUBLESHOOTING.md"
echo "================================================"
