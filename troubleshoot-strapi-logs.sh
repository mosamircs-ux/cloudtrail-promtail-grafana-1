#!/bin/bash
# Troubleshoot "No data" in Strapi Ceramic/Hypnotic panels - run on the EC2 instance

echo "=== Strapi Logs Troubleshooting ==="
echo ""

# 1. Hostname (must match Grafana query: ip-172-31-16-15 for Ceramic, ip-172-31-26-6 for Hypnotic)
HOSTNAME=$(hostname)
echo "1. Hostname (instance label sent to Loki): $HOSTNAME"
echo "   → Ceramic Home dashboard expects: ip-172-31-16-15"
echo "   → Hypnotic dashboard expects: ip-172-31-26-6"
if [[ "$HOSTNAME" != "ip-172-31-"* ]]; then
    echo "   ⚠ Hostname format may not match. Grafana queries instance=ip-172-31-X-X"
fi
echo ""

# 2. PM2 and Strapi
echo "2. PM2 apps:"
if command -v pm2 &>/dev/null; then
    pm2 list 2>/dev/null || echo "   pm2 list failed"
    echo ""
    echo "   Log files:"
    ls -la ~/.pm2/logs/*.log 2>/dev/null || ls -la /home/ubuntu/.pm2/logs/*.log 2>/dev/null || echo "   No PM2 logs found"
else
    echo "   ✗ PM2 not installed or not in PATH"
fi
echo ""

# 3. Promtail
echo "3. Promtail:"
if command -v promtail &>/dev/null; then
    echo "   ✓ Promtail installed"
    if systemctl is-active --quiet promtail 2>/dev/null || sudo systemctl is-active --quiet promtail 2>/dev/null; then
        echo "   ✓ Promtail service running"
    else
        echo "   ✗ Promtail NOT running - run: sudo systemctl start promtail"
    fi
    if [ -f /etc/promtail/promtail-config.yaml ]; then
        echo "   ✓ Config exists at /etc/promtail/promtail-config.yaml"
        echo "   Strapi paths in config:"
        grep -E "STRAPI|__path__" /etc/promtail/promtail-config.yaml 2>/dev/null | head -6 || true
    else
        echo "   ✗ No Promtail config - run setup-strapi-promtail.sh"
    fi
else
    echo "   ✗ Promtail not installed - run setup-strapi-promtail.sh"
fi
echo ""

# 4. Quick fix commands
echo "4. To fix 'No data' - run these on THIS instance:"
echo ""
echo "   # Copy project if needed:"
echo "   git clone <your-repo> cloudtrail-promtail-grafana-1  # or scp from your machine"
echo "   cd cloudtrail-promtail-grafana-1"
echo ""
echo "   # Run setup (enter app name when prompted, e.g. strapi-ceramic for Ceramic):"
echo "   chmod +x setup-strapi-promtail.sh"
echo "   ./setup-strapi-promtail.sh"
echo ""
echo "   # If Promtail already configured but not running:"
echo "   sudo systemctl restart promtail"
echo ""
echo "   # Check Promtail logs for errors:"
echo "   sudo journalctl -u promtail -n 50"
echo ""
