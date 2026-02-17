#!/bin/bash
# update-promtail-loki-url.sh
# Updates Promtail to send logs to your domain instead of IP

# === CONFIGURE THIS ===
# Option A: Same domain as Grafana, port 3100
NEW_LOKI_URL="http://157.175.59.166:3100/loki/api/v1/push"

# Option B: If using HTTP (no SSL on Loki port)
# NEW_LOKI_URL="http://grafana.mhg-int.com:3100/loki/api/v1/push"

# Old URL to replace
OLD_LOKI_URL="http://157.175.59.166:3100/loki/api/v1/push"

# === UPDATE PROMTAIL CONFIG ===
PROMTAIL_CONFIG="/etc/promtail/promtail-config.yaml"

if [ -f "$PROMTAIL_CONFIG" ]; then
    echo "Updating $PROMTAIL_CONFIG..."
    sudo sed -i "s|$OLD_LOKI_URL|$NEW_LOKI_URL|g" "$PROMTAIL_CONFIG"
    echo "Updated Loki URL to: $NEW_LOKI_URL"
    
    # Show the change
    echo ""
    echo "Current config:"
    grep -A2 "clients:" "$PROMTAIL_CONFIG"
    
    # Restart Promtail
    echo ""
    echo "Restarting Promtail..."
    sudo systemctl restart promtail
    sudo systemctl status promtail --no-pager
else
    echo "ERROR: $PROMTAIL_CONFIG not found!"
fi