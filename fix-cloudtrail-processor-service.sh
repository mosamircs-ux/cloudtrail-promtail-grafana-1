#!/bin/bash
# Fix cloudtrail-processor.service exit code 203
# Run on the EC2 where the processor is installed

set -e
echo "=== Fix CloudTrail Processor Service ==="
echo ""

# Detect OS user (Amazon Linux = ec2-user, Ubuntu = ubuntu)
if id ubuntu &>/dev/null; then
    RUN_AS=ubuntu
elif id ec2-user &>/dev/null; then
    RUN_AS=ec2-user
else
    RUN_AS=root
fi
echo "Using user: $RUN_AS"

# Ensure install directory exists
sudo mkdir -p /opt/cloudtrail-processor
sudo mkdir -p /var/log/cloudtrail-processed
sudo mkdir -p /var/lib/promtail

# Check if venv exists
if [ ! -x /opt/cloudtrail-processor/venv/bin/python ]; then
    echo "Creating Python venv (venv not found)..."
    cd /opt/cloudtrail-processor
    sudo -u $RUN_AS python3 -m venv venv 2>/dev/null || sudo python3 -m venv venv
    sudo -u $RUN_AS ./venv/bin/pip install --upgrade pip 2>/dev/null || true
    if [ -f requirements.txt ]; then
        sudo -u $RUN_AS ./venv/bin/pip install -r requirements.txt
    else
        sudo -u $RUN_AS ./venv/bin/pip install boto3 pyyaml
    fi
    echo "Venv created."
else
    echo "Venv exists at /opt/cloudtrail-processor/venv"
fi

# Copy updated service file (from current dir if running from project)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/cloudtrail-processor.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Error: cloudtrail-processor.service not found in $SCRIPT_DIR"
    exit 1
fi

# Apply User/Group for this OS
sed "s/User=ubuntu/User=$RUN_AS/g; s/Group=ubuntu/Group=$RUN_AS/g" "$SERVICE_FILE" | \
    sudo tee /etc/systemd/system/cloudtrail-processor.service > /dev/null

sudo systemctl daemon-reload
echo ""
echo "Restarting service..."
sudo systemctl restart cloudtrail-processor
sleep 2

if sudo systemctl is-active --quiet cloudtrail-processor; then
    echo ""
    echo "SUCCESS: cloudtrail-processor is running."
    sudo systemctl status cloudtrail-processor --no-pager -l | head -15
else
    echo ""
    echo "FAILED: Service still not running. Check logs:"
    sudo journalctl -u cloudtrail-processor -n 30 --no-pager
    exit 1
fi
