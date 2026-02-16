#!/bin/bash
# Troubleshoot: Why new EC2s don't show in Grafana
# Run this on EACH new EC2 to find the problem

LOKI_IP="${LOKI_IP:-16.24.169.121}"
LOKI_PORT="3100"

echo "=========================================="
echo "Promtail → Loki → Grafana Troubleshooter"
echo "=========================================="
echo ""
echo "Instance: $(hostname)"
echo "Loki target: $LOKI_IP:$LOKI_PORT"
echo ""

# 1. Promtail running?
echo "1. Promtail status:"
if systemctl is-active --quiet promtail 2>/dev/null; then
    echo "   ✓ Promtail is RUNNING"
elif pgrep -x promtail >/dev/null; then
    echo "   ✓ Promtail process found (not systemd)"
else
    echo "   ✗ Promtail is NOT running"
    echo "   Fix: sudo systemctl start promtail (or run install-promtail-on-ec2.sh)"
fi
echo ""

# 2. Can we reach Loki?
echo "2. Loki connectivity:"
READY=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "http://$LOKI_IP:$LOKI_PORT/ready" 2>/dev/null || echo "000")
if [ "$READY" = "200" ]; then
    echo "   ✓ Loki is reachable at $LOKI_IP:$LOKI_PORT"
else
    echo "   ✗ Cannot reach Loki (got HTTP $READY)"
    echo "   Fix: Security group on $LOKI_IP - allow inbound port 3100 from this EC2"
    echo "   Test manually: curl http://$LOKI_IP:3100/ready"
fi
echo ""

# 3. Promtail config
echo "3. Promtail config:"
CONFIG="/etc/promtail/promtail-config.yaml"
if [ -f "$CONFIG" ]; then
    echo "   Config: $CONFIG"
    grep -E "url:|instance:" "$CONFIG" 2>/dev/null | sed 's/^/   /'
else
    echo "   ✗ Config not found at $CONFIG"
fi
echo ""

# 4. Log file exists?
echo "4. Log file to tail:"
for f in /var/log/syslog /var/log/messages; do
    if [ -f "$f" ]; then
        echo "   ✓ $f exists"
    else
        echo "   - $f missing"
    fi
done
echo ""

# 5. Recent Promtail logs
echo "5. Recent Promtail logs (last 5 lines):"
journalctl -u promtail -n 5 --no-pager 2>/dev/null || echo "   (no journalctl output)"
echo ""

# 6. Test push (if promtail running)
echo "6. Summary:"
echo "   If Loki unreachable → Open port 3100 on $LOKI_IP for this EC2"
echo "   If Promtail not running → Run: ./install-promtail-on-ec2.sh"
echo "   If config wrong → Edit $CONFIG, set url and instance label"
echo ""
