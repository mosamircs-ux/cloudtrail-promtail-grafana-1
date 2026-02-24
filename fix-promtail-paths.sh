#!/bin/bash
# Fix Promtail paths and restart services
# Run on EC2: chmod +x fix-promtail-paths.sh && sudo ./fix-promtail-paths.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "🔧 Fix Promtail Paths & Restart Services"
echo "=========================================="
echo ""

# Detect user
if [ -d "/home/ubuntu" ]; then
    USER_NAME="ubuntu"
elif [ -d "/home/ec2-user" ]; then
    USER_NAME="ec2-user"
else
    USER_NAME=$(whoami)
fi
echo "Detected user: $USER_NAME"

# Get instance hostname
INSTANCE_NAME=$(hostname)
echo "Instance: $INSTANCE_NAME"
echo ""

# ==========================================
# Step 1: Find CloudTrail logs path
# ==========================================
echo "1️⃣ Finding CloudTrail processed logs..."

CLOUDTRAIL_PATHS=(
    "/var/log/cloudtrail-processed"
    "/opt/cloudtrail-processor/logs"
    "/var/log/cloudtrail"
)

CLOUDTRAIL_PATH=""
for path in "${CLOUDTRAIL_PATHS[@]}"; do
    if [ -d "$path" ]; then
        CLOUDTRAIL_PATH="$path"
        FILE_COUNT=$(ls -1 "$path"/*.log 2>/dev/null | wc -l)
        echo -e "   ${GREEN}✓ Found: $path ($FILE_COUNT log files)${NC}"
        break
    fi
done

if [ -z "$CLOUDTRAIL_PATH" ]; then
    echo -e "   ${YELLOW}⚠ Creating /var/log/cloudtrail-processed${NC}"
    CLOUDTRAIL_PATH="/var/log/cloudtrail-processed"
    sudo mkdir -p "$CLOUDTRAIL_PATH"
    sudo chown -R $USER_NAME:$USER_NAME "$CLOUDTRAIL_PATH"
fi
echo ""

# ==========================================
# Step 2: Find Laravel logs path
# ==========================================
echo "2️⃣ Finding Laravel logs..."

LARAVEL_PATHS=(
    "/var/www/mhg/storage/logs"
    "/var/www/html/storage/logs"
    "/var/www/hatch/storage/logs"
    "/var/www/html/backend-maintenance-reminder/storage/logs"
    "/var/www/laravel/storage/logs"
)

LARAVEL_PATH=""
for path in "${LARAVEL_PATHS[@]}"; do
    if [ -d "$path" ]; then
        LARAVEL_PATH="$path"
        FILE_COUNT=$(ls -1 "$path"/*.log 2>/dev/null | wc -l)
        echo -e "   ${GREEN}✓ Found: $path ($FILE_COUNT log files)${NC}"
        break
    fi
done

if [ -z "$LARAVEL_PATH" ]; then
    echo -e "   ${YELLOW}⚠ No Laravel logs found - skipping Laravel config${NC}"
fi
echo ""

# ==========================================
# Step 3: Get Loki URL
# ==========================================
echo "3️⃣ Configuring Loki URL..."

# Default Loki URL - CHANGE THIS if different
LOKI_URL="http://157.175.59.166:3100/loki/api/v1/push"

# Test Loki connectivity
echo "   Testing Loki at $LOKI_URL..."
if curl -s --connect-timeout 5 "http://157.175.59.166:3100/ready" | grep -q "ready"; then
    echo -e "   ${GREEN}✓ Loki is reachable${NC}"
else
    echo -e "   ${YELLOW}⚠ Loki not responding - check IP and port${NC}"
    echo "   Current URL: $LOKI_URL"
    read -p "   Enter correct Loki IP (or press Enter to keep): " NEW_IP
    if [ -n "$NEW_IP" ]; then
        LOKI_URL="http://$NEW_IP:3100/loki/api/v1/push"
    fi
fi
echo ""

# ==========================================
# Step 4: Create/Update Promtail config
# ==========================================
echo "4️⃣ Creating Promtail config..."

PROMTAIL_CONFIG="/etc/promtail/promtail-config.yaml"

# Backup existing config
if [ -f "$PROMTAIL_CONFIG" ]; then
    sudo cp "$PROMTAIL_CONFIG" "${PROMTAIL_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
    echo "   Backed up existing config"
fi

# Create directories
sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail
sudo chown -R $USER_NAME:$USER_NAME /var/lib/promtail

# Write new config
sudo tee "$PROMTAIL_CONFIG" > /dev/null << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: $LOKI_URL

scrape_configs:
  # CloudTrail processed logs
  - job_name: cloudtrail
    static_configs:
      - targets:
          - localhost
        labels:
          job: cloudtrail
          instance: $INSTANCE_NAME
          __path__: $CLOUDTRAIL_PATH/*.log

  # System syslog
  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          instance: $INSTANCE_NAME
          __path__: /var/log/syslog
EOF

# Add Laravel job if path exists
if [ -n "$LARAVEL_PATH" ]; then
    sudo tee -a "$PROMTAIL_CONFIG" > /dev/null << EOF

  # Laravel application logs
  - job_name: laravel
    static_configs:
      - targets:
          - localhost
        labels:
          job: laravel
          instance: $INSTANCE_NAME
          __path__: $LARAVEL_PATH/*.log
EOF
fi

echo -e "   ${GREEN}✓ Config created at $PROMTAIL_CONFIG${NC}"
echo ""

# ==========================================
# Step 5: Fix permissions
# ==========================================
echo "5️⃣ Fixing permissions..."

sudo chmod 644 "$CLOUDTRAIL_PATH"/*.log 2>/dev/null || true
sudo chmod 755 "$CLOUDTRAIL_PATH"

if [ -n "$LARAVEL_PATH" ]; then
    sudo chmod 644 "$LARAVEL_PATH"/*.log 2>/dev/null || true
    sudo chmod 755 "$LARAVEL_PATH"
fi

echo -e "   ${GREEN}✓ Permissions fixed${NC}"
echo ""

# ==========================================
# Step 6: Restart CloudTrail Processor
# ==========================================
echo "6️⃣ Restarting CloudTrail Processor..."

if systemctl list-units --type=service | grep -q "cloudtrail-processor"; then
    sudo systemctl restart cloudtrail-processor
    sleep 2
    if systemctl is-active --quiet cloudtrail-processor; then
        echo -e "   ${GREEN}✓ CloudTrail Processor running${NC}"
    else
        echo -e "   ${RED}✗ CloudTrail Processor failed to start${NC}"
        echo "   Check: sudo journalctl -u cloudtrail-processor -n 20"
    fi
else
    echo -e "   ${YELLOW}⚠ CloudTrail Processor service not found${NC}"
fi
echo ""

# ==========================================
# Step 7: Restart Promtail
# ==========================================
echo "7️⃣ Restarting Promtail..."

sudo systemctl restart promtail
sleep 3

if systemctl is-active --quiet promtail; then
    echo -e "   ${GREEN}✓ Promtail running${NC}"
else
    echo -e "   ${RED}✗ Promtail failed to start${NC}"
    echo "   Check: sudo journalctl -u promtail -n 20"
fi
echo ""

# ==========================================
# Step 8: Verify
# ==========================================
echo "8️⃣ Verification..."

echo ""
echo "=== Promtail Config ==="
grep -A2 "clients:" "$PROMTAIL_CONFIG"
echo ""
grep "__path__:" "$PROMTAIL_CONFIG"

echo ""
echo "=== Log Files ==="
echo "CloudTrail logs:"
ls -lh "$CLOUDTRAIL_PATH"/*.log 2>/dev/null | tail -3 || echo "   No files yet"

if [ -n "$LARAVEL_PATH" ]; then
    echo ""
    echo "Laravel logs:"
    ls -lh "$LARAVEL_PATH"/*.log 2>/dev/null | tail -3 || echo "   No files"
fi

echo ""
echo "=== Recent Promtail Activity ==="
sudo journalctl -u promtail --no-pager -n 10 | grep -E "tail routine|batch|error" | tail -5

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Done!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Wait 1-2 minutes for logs to flow"
echo "2. Check Grafana Explore: {instance=\"$INSTANCE_NAME\"}"
echo "3. If still no data, check:"
echo "   sudo journalctl -u promtail -f"
echo "   sudo journalctl -u cloudtrail-processor -f"
echo ""
