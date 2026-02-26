#!/bin/bash
# One-command setup for Ceramic Home (ip-172-31-16-15) - no prompts
# Run on the Ceramic EC2 instance: ./setup-ceramic-promtail.sh

set -e

APP_NAME="strapi"
LOKI_URL="http://157.175.59.166:3100/loki/api/v1/push"

echo "=== Ceramic Strapi → Promtail (non-interactive) ==="
echo ""

# Find PM2 logs
for path in /home/ubuntu/.pm2/logs /home/ec2-user/.pm2/logs /root/.pm2/logs; do
    if [ -d "$path" ] && ls "$path"/*.log &>/dev/null 2>&1; then
        PM2_LOG_PATH="$path"
        break
    fi
done
[ -z "$PM2_LOG_PATH" ] && [ -d "$HOME/.pm2/logs" ] && PM2_LOG_PATH="$HOME/.pm2/logs"

if [ -z "$PM2_LOG_PATH" ]; then
    echo "✗ PM2 logs not found at ~/.pm2/logs"
    exit 1
fi

STRAPI_LOG_PATH="$PM2_LOG_PATH/${APP_NAME}*.log"
STRAPI_ERROR_PATH="$PM2_LOG_PATH/${APP_NAME}*error*.log"
INSTANCE_ID=$(hostname)

echo "   PM2 path: $PM2_LOG_PATH"
echo "   App: $APP_NAME → Logs: $STRAPI_LOG_PATH"
echo "   Instance: $INSTANCE_ID"
echo ""

# Install Promtail if needed
if ! command -v promtail &>/dev/null; then
    echo "Installing Promtail..."
    cd /tmp
    curl -sL -O "https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip"
    unzip -q -o promtail-linux-amd64.zip
    sudo mv promtail-linux-amd64 /usr/local/bin/promtail
    sudo chmod +x /usr/local/bin/promtail
    rm -f promtail-linux-amd64.zip
fi

# Create config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/promtail-strapi-config.yaml" ]; then
    echo "✗ promtail-strapi-config.yaml not found"
    exit 1
fi

sudo mkdir -p /etc/promtail /var/lib/promtail

sed "s/INSTANCE_ID/$INSTANCE_ID/g" "$SCRIPT_DIR/promtail-strapi-config.yaml" | \
    sed "s|STRAPI_LOG_PATH|$STRAPI_LOG_PATH|g" | \
    sed "s|STRAPI_ERROR_PATH|$STRAPI_ERROR_PATH|g" | \
    sed "s|url: .*|url: $LOKI_URL|" > /tmp/promtail-config.yaml

# Fix syslog for Amazon Linux
[ ! -f /var/log/syslog ] && [ -f /var/log/messages ] && \
    sed -i 's|/var/log/syslog|/var/log/messages|g; s|job: syslog|job: messages|g; s|job_name: syslog|job_name: messages|g' /tmp/promtail-config.yaml

sudo cp /tmp/promtail-config.yaml /etc/promtail/promtail-config.yaml

# Reset positions so Promtail re-reads existing logs
sudo rm -f /var/lib/promtail/positions.yaml
echo "   ✓ Positions reset (will re-read existing logs)"

# Permissions
sudo chmod 644 "$PM2_LOG_PATH"/*.log 2>/dev/null || true

# Service
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

sleep 2
if sudo systemctl is-active --quiet promtail; then
    echo ""
    echo "✓ SUCCESS - Ceramic logs flowing to Loki"
    echo "  Wait 30-60 seconds, then check Grafana: {job=\"strapi\", instance=\"$INSTANCE_ID\"}"
else
    echo "✗ Promtail failed:"
    /usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml 2>&1 | head -15
    exit 1
fi
