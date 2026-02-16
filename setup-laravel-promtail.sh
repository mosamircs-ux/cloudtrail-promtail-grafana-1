#!/bin/bash
# Setup Promtail for Laravel logs - run on EC2 where Laravel is installed

set -e

echo "=== Laravel Logs → Promtail Setup ==="
echo ""

# 1. Find Laravel logs
echo "1. Finding Laravel log directory..."
POSSIBLE_PATHS=(
    "/var/www/html/storage/logs"
    "/var/www/laravel/storage/logs"
    "/home/ubuntu/app/storage/logs"
    "/home/ubuntu/laravel/storage/logs"
    "/opt/laravel/storage/logs"
)

LARAVEL_LOG_PATH=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ] && ls "$path"/*.log &>/dev/null; then
        LARAVEL_LOG_PATH="$path"
        echo "   ✓ Found Laravel logs: $LARAVEL_LOG_PATH"
        ls -lh "$LARAVEL_LOG_PATH" | head -5
        break
    fi
done

if [ -z "$LARAVEL_LOG_PATH" ]; then
    echo "   ✗ Laravel logs not found in common paths."
    echo ""
    read -p "Enter your Laravel storage/logs path: " LARAVEL_LOG_PATH
    if [ ! -d "$LARAVEL_LOG_PATH" ]; then
        echo "Path doesn't exist: $LARAVEL_LOG_PATH"
        exit 1
    fi
fi

# 2. Ensure Promtail is installed
echo ""
echo "2. Checking Promtail installation..."
if ! command -v promtail &>/dev/null; then
    echo "   Installing Promtail..."
    cd /tmp
    curl -sL -O "https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip"
    unzip -q -o promtail-linux-amd64.zip
    sudo mv promtail-linux-amd64 /usr/local/bin/promtail
    sudo chmod +x /usr/local/bin/promtail
    echo "   ✓ Promtail installed"
else
    echo "   ✓ Promtail already installed"
fi

# 3. Create Promtail config
echo ""
echo "3. Configuring Promtail..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/promtail-ec2-config.yaml" ]; then
    echo "   ✗ promtail-ec2-config.yaml not found"
    exit 1
fi

INSTANCE_ID=$(hostname)
sudo mkdir -p /etc/promtail

# Copy and customize config
sed "s/INSTANCE_ID/$INSTANCE_ID/g" "$SCRIPT_DIR/promtail-ec2-config.yaml" > /tmp/promtail-config.yaml
sed -i "s|__path__: /var/www/html/storage/logs/\*.log|__path__: $LARAVEL_LOG_PATH/*.log|" /tmp/promtail-config.yaml

# Prompt for Loki URL
echo ""
read -p "Enter Loki URL (default: http://16.24.169.121:3100/loki/api/v1/push): " LOKI_URL
LOKI_URL=${LOKI_URL:-http://16.24.169.121:3100/loki/api/v1/push}
sed -i "s|url: .*|url: $LOKI_URL|" /tmp/promtail-config.yaml

sudo cp /tmp/promtail-config.yaml /etc/promtail/promtail-config.yaml
echo "   ✓ Config installed with Laravel path: $LARAVEL_LOG_PATH/*.log"

# 4. Fix permissions
echo ""
echo "4. Setting log permissions..."
sudo chmod 644 "$LARAVEL_LOG_PATH"/*.log 2>/dev/null || true
echo "   ✓ Logs readable"

# 5. Create/update service
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

# 6. Verify
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

# 7. Generate test log
echo ""
echo "7. Generating test Laravel log..."
TEST_LOG="$LARAVEL_LOG_PATH/test-grafana.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] production.INFO: Test log from setup script" | sudo tee "$TEST_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] production.ERROR: Test error from setup script" | sudo tee -a "$TEST_LOG"
sudo chmod 644 "$TEST_LOG"
echo "   ✓ Test logs written to $TEST_LOG"

echo ""
echo "SUCCESS! Laravel logs are now being sent to Loki."
echo ""
echo "Next steps:"
echo "  1. Wait 30-60 seconds for logs to appear"
echo "  2. In Grafana → Explore, query: {job=\"laravel\"}"
echo "  3. Import/refresh grafana-main-dashboard.json to see Laravel Logs table"
echo ""
echo "Instance name in dashboard: $INSTANCE_ID"
echo ""
