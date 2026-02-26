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
    if ! pm2 list 2>/dev/null | grep -q "online\|errored"; then
        echo ""
        echo "   ⚠ NO PM2 APPS RUNNING - Strapi must run to generate new logs!"
        echo "   Fix: cd /var/www/strapi-ceramic && pm2 start npm --name strapi -- run develop"
    fi
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
echo "4. To fix 'No data':"
echo ""
echo "   A) START STRAPI (most likely fix - PM2 apps were empty!):"
echo "      cd /var/www/strapi-ceramic   # or your Strapi app path"
echo "      pm2 start npm --name strapi -- run develop"
echo "      # Or: pm2 resurrect   (if you had saved the process list)"
echo ""
echo "   B) Reset Promtail to re-read existing logs (then restart):"
echo "      sudo rm -f /var/lib/promtail/positions.yaml"
echo "      sudo systemctl restart promtail"
echo ""
echo "   C) If Promtail not set up or config wrong:"
echo "      cd cloudtrail-promtail-grafana-1"
echo "      ./setup-strapi-promtail.sh   # enter: strapi when prompted"
echo ""
echo "   D) Check Loki connectivity:"
echo "      curl -s -o /dev/null -w '%{http_code}' http://157.175.59.166:3100/ready"
echo ""
