#!/bin/bash
# Diagnose why Laravel logs aren't appearing in Grafana
# Run on the EC2 where Laravel is installed

echo "=== Laravel Logs Diagnostic ==="
echo ""

# Common Laravel paths
POSSIBLE_PATHS=(
    "/var/www/html/storage/logs"
    "/var/www/laravel/storage/logs"
    "/home/ubuntu/app/storage/logs"
    "/home/ubuntu/laravel/storage/logs"
    "/opt/laravel/storage/logs"
)

echo "1. Checking for Laravel log directories..."
FOUND_PATH=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo "   ✓ Found: $path"
        FOUND_PATH="$path"
        LOG_COUNT=$(ls -1 "$path"/*.log 2>/dev/null | wc -l)
        echo "      Log files: $LOG_COUNT"
        if [ $LOG_COUNT -gt 0 ]; then
            ls -lh "$path"/*.log | head -5
        fi
    else
        echo "   ✗ Not found: $path"
    fi
done

if [ -z "$FOUND_PATH" ]; then
    echo ""
    echo "   ⚠️  No Laravel logs directory found. Checked common paths."
    echo "   Find your Laravel installation and check storage/logs/"
    echo ""
else
    echo ""
    echo "2. Checking log file permissions..."
    ls -lh "$FOUND_PATH"/*.log 2>/dev/null | head -3
    
    echo ""
    echo "3. Checking if Promtail can read logs..."
    PROMTAIL_USER=$(ps aux | grep promtail | grep -v grep | awk '{print $1}' | head -1)
    if [ -n "$PROMTAIL_USER" ]; then
        echo "   Promtail runs as: $PROMTAIL_USER"
        if sudo -u $PROMTAIL_USER cat "$FOUND_PATH"/laravel*.log > /dev/null 2>&1; then
            echo "   ✓ $PROMTAIL_USER can read Laravel logs"
        else
            echo "   ✗ $PROMTAIL_USER CANNOT read Laravel logs (permission issue)"
            echo ""
            echo "   Fix: sudo chmod 644 $FOUND_PATH/*.log"
            echo "   Or: sudo usermod -aG www-data $PROMTAIL_USER  (if Laravel runs as www-data)"
        fi
    else
        echo "   ⚠️  Promtail not running"
    fi
fi

echo ""
echo "4. Checking Promtail config..."
PROMTAIL_CONFIG="/etc/promtail/promtail-config.yaml"
if [ -f "$PROMTAIL_CONFIG" ]; then
    if grep -q "job: laravel" "$PROMTAIL_CONFIG"; then
        echo "   ✓ Laravel job configured in $PROMTAIL_CONFIG"
        CONFIG_PATH=$(grep -A5 "job: laravel" "$PROMTAIL_CONFIG" | grep "__path__" | awk '{print $2}')
        echo "      Configured path: $CONFIG_PATH"
        
        # Check if path matches found Laravel
        if [ -n "$FOUND_PATH" ] && [ "$CONFIG_PATH" != "$FOUND_PATH/*.log" ]; then
            echo "      ⚠️  Path mismatch! Config has $CONFIG_PATH but Laravel is at $FOUND_PATH"
            echo ""
            echo "      Fix: sudo sed -i 's|__path__: .*laravel.*|__path__: $FOUND_PATH/*.log|' $PROMTAIL_CONFIG"
            echo "           sudo systemctl restart promtail"
        fi
    else
        echo "   ✗ Laravel job NOT configured in $PROMTAIL_CONFIG"
        echo ""
        echo "   Add Laravel job to Promtail config:"
        echo "   sudo nano $PROMTAIL_CONFIG"
        echo "   (or copy from promtail-ec2-config.yaml or promtail-laravel-config.yaml)"
    fi
else
    echo "   ✗ Promtail config not found at $PROMTAIL_CONFIG"
fi

echo ""
echo "5. Checking Promtail service status..."
if systemctl is-active --quiet promtail; then
    echo "   ✓ Promtail is running"
else
    echo "   ✗ Promtail is NOT running"
    echo "   Start: sudo systemctl start promtail"
fi

echo ""
echo "6. Checking recent Laravel log entries..."
if [ -n "$FOUND_PATH" ]; then
    LATEST_LOG=$(ls -t "$FOUND_PATH"/*.log 2>/dev/null | head -1)
    if [ -f "$LATEST_LOG" ]; then
        echo "   Latest: $LATEST_LOG"
        echo "   Last 3 lines:"
        tail -3 "$LATEST_LOG" | sed 's/^/      /'
    fi
fi

echo ""
echo "7. Test query in Grafana Explore..."
echo "   Query: {job=\"laravel\"}"
echo "   If empty: Promtail isn't sending Laravel logs to Loki"
echo ""
echo "8. Quick fix summary:"
if [ -n "$FOUND_PATH" ]; then
    echo "   # Update Promtail config to use correct path:"
    echo "   sudo sed -i 's|__path__:.*laravel.*|__path__: $FOUND_PATH/*.log|' $PROMTAIL_CONFIG"
    echo "   sudo chmod 644 $FOUND_PATH/*.log"
    echo "   sudo systemctl restart promtail"
    echo ""
    echo "   # Generate test log:"
    echo "   echo '[$(date '+%Y-%m-%d %H:%M:%S')] production.ERROR: Test from Grafana' | sudo tee -a $FOUND_PATH/test.log"
fi
echo ""
