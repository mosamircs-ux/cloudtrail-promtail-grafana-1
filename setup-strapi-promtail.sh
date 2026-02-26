#!/bin/bash
# Setup Promtail for Strapi logs - run on EC2 where Strapi runs under PM2

set -e

echo "=== Strapi Logs → Promtail Setup ==="
echo ""

# 1. Find PM2 logs directory
echo "1. Finding PM2 log directory..."
POSSIBLE_PATHS=(
    "/home/ubuntu/.pm2/logs"
    "/home/ec2-user/.pm2/logs"
    "/root/.pm2/logs"
)

PM2_LOG_PATH=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ] && ls "$path"/*.log &>/dev/null 2>&1; then
        PM2_LOG_PATH="$path"
        echo "   ✓ Found PM2 logs: $PM2_LOG_PATH"
        ls "$PM2_LOG_PATH"/*.log 2>/dev/null | head -6
        break
    fi
done

# Fallback: check $HOME
if [ -z "$PM2_LOG_PATH" ] && [ -d "$HOME/.pm2/logs" ]; then
    PM2_LOG_PATH="$HOME/.pm2/logs"
    echo "   ✓ Found PM2 logs: $PM2_LOG_PATH"
fi

if [ -z "$PM2_LOG_PATH" ]; then
    echo "   ✗ PM2 logs not found. Is Strapi running under PM2?"
    echo ""
    read -p "Enter your PM2 logs path (e.g. /home/ubuntu/.pm2/logs): " PM2_LOG_PATH
    if [ ! -d "$PM2_LOG_PATH" ]; then
        echo "Path doesn't exist: $PM2_LOG_PATH"
        exit 1
    fi
fi

# 2. Detect Strapi app name from PM2 (optional)
APP_PATTERN="*.log"
if command -v pm2 &>/dev/null; then
    echo ""
    echo "   PM2 apps:"
    pm2 list 2>/dev/null | tail -n +4 || true
    echo ""
    read -p "Enter Strapi app name for log glob (e.g. strapi, my-cms) or press Enter for all (*.log): " APP_NAME
    if [ -n "$APP_NAME" ]; then
        APP_PATTERN="${APP_NAME}*.log"
        echo "   Using: $PM2_LOG_PATH/$APP_PATTERN"
    fi
fi

STRAPI_LOG_PATH="$PM2_LOG_PATH/$APP_PATTERN"

# Explicit error log path - ensures PM2 -error.log reaches Grafana
if [ -n "$APP_NAME" ]; then
    STRAPI_ERROR_PATH="$PM2_LOG_PATH/${APP_NAME}-error.log"
else
    STRAPI_ERROR_PATH="$PM2_LOG_PATH/*-error.log"
fi
echo "   Error logs path: $STRAPI_ERROR_PATH"
# Warn if error log doesn't exist yet (PM2 creates it when first error occurs)
if [ -n "$APP_NAME" ] && [ ! -f "$STRAPI_ERROR_PATH" ]; then
    echo "   ⚠ Error file not yet created (PM2 creates it on first stderr output)"
fi

# 3. Ensure Promtail is installed
echo ""
echo "2. Checking Promtail installation..."
if ! command -v promtail &>/dev/null; then
    echo "   Installing Promtail..."
    cd /tmp
    curl -sL -O "https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip"
    unzip -q -o promtail-linux-amd64.zip
    sudo mv promtail-linux-amd64 /usr/local/bin/promtail
    sudo chmod +x /usr/local/bin/promtail
    rm -f promtail-linux-amd64.zip
    echo "   ✓ Promtail installed"
else
    echo "   ✓ Promtail already installed"
fi

# 4. Create Promtail config
echo ""
echo "3. Configuring Promtail..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/promtail-strapi-config.yaml" ]; then
    echo "   ✗ promtail-strapi-config.yaml not found"
    exit 1
fi

INSTANCE_ID=$(hostname)
sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail

# Copy and customize config
sed "s/INSTANCE_ID/$INSTANCE_ID/g" "$SCRIPT_DIR/promtail-strapi-config.yaml" | \
    sed "s|STRAPI_LOG_PATH|$STRAPI_LOG_PATH|g" | \
    sed "s|STRAPI_ERROR_PATH|$STRAPI_ERROR_PATH|g" > /tmp/promtail-config.yaml

# Amazon Linux uses /var/log/messages, Ubuntu uses /var/log/syslog - fix if syslog missing
if [ ! -f /var/log/syslog ] && [ -f /var/log/messages ]; then
    sed -i 's|job_name: syslog|job_name: messages|' /tmp/promtail-config.yaml
    sed -i 's|job: syslog|job: messages|' /tmp/promtail-config.yaml
    sed -i 's|/var/log/syslog|/var/log/messages|' /tmp/promtail-config.yaml
fi

# Prompt for Loki URL
echo ""
read -p "Enter Loki URL (default: http://157.175.59.166:3100/loki/api/v1/push): " LOKI_URL
LOKI_URL=${LOKI_URL:-http://157.175.59.166:3100/loki/api/v1/push}
sed -i "s|url: .*|url: $LOKI_URL|" /tmp/promtail-config.yaml

sudo cp /tmp/promtail-config.yaml /etc/promtail/promtail-config.yaml
echo "   ✓ Config installed - logs: $STRAPI_LOG_PATH"
echo "   ✓ Error logs: $STRAPI_ERROR_PATH"

# 5. Fix permissions (includes both -out.log and -error.log)
echo ""
echo "4. Setting log permissions..."
sudo chmod 644 "$PM2_LOG_PATH"/*.log 2>/dev/null || true
sudo chmod 755 "$PM2_LOG_PATH"
echo "   ✓ Logs readable"
echo "   (Includes: *-out.log and *-error.log - errors flow to Loki)"

# 6. Create/update service
echo ""
echo "5. Installing Promtail service..."
sudo tee /etc/systemd/system/promtail.service > /dev/null << 'EOF'
[Unit]
Description=Promtail for EC2 logs to Loki
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl restart promtail
echo "   ✓ Promtail service started"

# 7. Verify
echo ""
echo "6. Verifying..."
sleep 2

if sudo systemctl is-active --quiet promtail; then
    echo "   ✓ Promtail is running"
else
    echo "   ✗ Promtail failed to start"
    sudo systemctl status promtail --no-pager -l | head -20
    exit 1
fi

echo ""
echo "SUCCESS! Strapi (PM2) logs are now being sent to Loki."
echo ""
echo "Next steps:"
echo "  1. Wait 30-60 seconds for logs to appear"
echo "  2. In Grafana → Explore, query: {job=\"strapi\"}"
echo "  3. Dashboard has 'Errors Only' tables for Ceramic & Hypnotic"
echo "  4. Trigger some Strapi activity to generate logs"
echo ""
echo "Instance name in dashboard: $INSTANCE_ID"
echo ""
