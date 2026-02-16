#!/bin/bash
# Install Promtail on an EC2 instance - Run this ON EACH EC2 (except CloudTrail processor)
# This makes the EC2 show up in the Main dashboard
#
# Usage: 
#   1. Copy this script + promtail-ec2-config.yaml to the EC2 (or git clone the repo)
#   2. Edit LOKI_URL below if needed
#   3. Run: chmod +x install-promtail-on-ec2.sh && ./install-promtail-on-ec2.sh

set -e

LOKI_URL="http://16.24.169.121:3100/loki/api/v1/push"  # <<< Change to your Loki server IP

echo "=========================================="
echo "Promtail Install - EC2 to Loki"
echo "=========================================="
echo ""

# 1. Install Promtail binary
if ! command -v promtail &>/dev/null; then
    echo "Installing Promtail..."
    cd /tmp
    curl -sL -O "https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip"
    unzip -q -o promtail-linux-amd64.zip
    sudo mv promtail-linux-amd64 /usr/local/bin/promtail
    sudo chmod +x /usr/local/bin/promtail
    rm -f promtail-linux-amd64.zip
    echo "✓ Promtail installed"
else
    echo "✓ Promtail already installed"
fi

# 2. Create config with this instance's hostname
INSTANCE_ID=$(hostname)
echo "Instance label: $INSTANCE_ID"
echo ""

CONFIG_DIR="${CONFIG_DIR:-/etc/promtail}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/promtail-ec2-config.yaml" ]; then
    sed "s/INSTANCE_ID/$INSTANCE_ID/g" "$SCRIPT_DIR/promtail-ec2-config.yaml" > /tmp/promtail-ec2.yaml
    sed -i "s|url: .*|url: $LOKI_URL|" /tmp/promtail-ec2.yaml
else
    echo "Error: promtail-ec2-config.yaml not found in $SCRIPT_DIR"
    echo "Run this script from the project directory or set CONFIG_DIR"
    exit 1
fi

# 3. Install config and create dirs
sudo mkdir -p $CONFIG_DIR /var/lib/promtail
sudo cp /tmp/promtail-ec2.yaml $CONFIG_DIR/promtail-config.yaml
echo "✓ Config installed to $CONFIG_DIR/promtail-config.yaml"

# 4. Create systemd service
sudo tee /etc/systemd/system/promtail.service > /dev/null << EOF
[Unit]
Description=Promtail for EC2 logs to Loki
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=$CONFIG_DIR/promtail-config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail
echo "✓ Promtail service started"

echo ""
echo "Done! This EC2 will appear in the Main dashboard as: $INSTANCE_ID"
echo "Check status: sudo systemctl status promtail"
echo ""
echo "If Promtail fails to start: Ubuntu uses /var/log/syslog, Amazon Linux uses /var/log/messages."
echo "Edit $CONFIG_DIR/promtail-config.yaml and comment out the job for the path that doesn't exist."
echo ""
