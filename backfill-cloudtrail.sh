#!/bin/bash
# Backfill ALL CloudTrail logs from S3 - gets full history of all users, access keys, resources
# Use this when you're only seeing your own data and want to load everything
#
# Run on the EC2 where the CloudTrail processor runs

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=========================================="
echo "CloudTrail Full Backfill"
echo "==========================================${NC}"
echo ""
echo "This will:"
echo "1. Clear processing state (so we reprocess from scratch)"
echo "2. Increase initial lookback to 90 days in config"
echo "3. Restart the processor to reload ALL logs"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

CONFIG="${CONFIG_PATH:-/opt/cloudtrail-processor/config.yaml}"
STATE="${STATE_PATH:-/var/lib/promtail/cloudtrail-state.json}"
STATE_DIR=$(dirname "$STATE")

# Create state directory if needed
sudo mkdir -p "$STATE_DIR"
echo -e "${GREEN}Ensured state directory exists${NC}"

# Backup state
if [ -f "$STATE" ]; then
    cp "$STATE" "${STATE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}Backed up state file${NC}"
fi

# Clear state
echo '{"last_processed_time": null, "processed_files": []}' | sudo tee "$STATE" > /dev/null
echo -e "${GREEN}Cleared processing state${NC}"

# Update config for 90-day lookback
if [ -f "$CONFIG" ]; then
    if grep -q "initial_lookback_days" "$CONFIG"; then
        sudo sed -i 's/initial_lookback_days: .*/initial_lookback_days: 90/' "$CONFIG"
    else
        echo "initial_lookback_days: 90" | sudo tee -a "$CONFIG"
    fi
    echo -e "${GREEN}Set lookback to 90 days${NC}"
fi

# Restart processor
echo ""
echo -e "${YELLOW}Restarting CloudTrail processor...${NC}"
sudo systemctl restart cloudtrail-processor 2>/dev/null || {
    echo -e "${YELLOW}Service not found - run the processor manually:${NC}"
    echo "  cd /opt/cloudtrail-processor && ./venv/bin/python cloudtrail_processor.py"
}

echo ""
echo -e "${GREEN}Done! The processor will now load logs from the last 90 days.${NC}"
echo "Monitor progress: sudo journalctl -u cloudtrail-processor -f"
echo ""
