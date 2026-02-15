#!/bin/bash
# Deploy the updated CloudTrail processor with enhanced resource extraction
# This fixes the issue where only CloudTrail bucket was showing in Grafana dashboard

set -e

echo "==================================="
echo "CloudTrail Processor Update Script"
echo "Fixing Resource Extraction Issue"
echo "==================================="
echo ""

# Check if script is in the right location
if [ ! -f "cloudtrail_processor.py" ]; then
    echo "❌ Error: cloudtrail_processor.py not found in current directory"
    echo "Please run this script from the cloudtrail-promtail-setup directory"
    exit 1
fi

echo "✓ Found cloudtrail_processor.py"
echo ""

# Backup current version
echo "📦 Creating backup of current processor..."
if [ -f "/opt/cloudtrail-processor/cloudtrail_processor.py" ]; then
    sudo cp /opt/cloudtrail-processor/cloudtrail_processor.py \
           /opt/cloudtrail-processor/cloudtrail_processor.py.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ Backup created"
else
    echo "⚠ Warning: No existing processor found at /opt/cloudtrail-processor/"
    echo "This might be a fresh installation"
fi
echo ""

# Copy updated version
echo "🔄 Installing updated processor..."
sudo cp cloudtrail_processor.py /opt/cloudtrail-processor/cloudtrail_processor.py
sudo chown root:root /opt/cloudtrail-processor/cloudtrail_processor.py
sudo chmod 755 /opt/cloudtrail-processor/cloudtrail_processor.py
echo "✓ Updated processor installed"
echo ""

# Restart service
echo "🔄 Restarting cloudtrail-processor service..."
sudo systemctl restart cloudtrail-processor
sleep 2
echo ""

# Check status
echo "📊 Checking service status..."
if sudo systemctl is-active --quiet cloudtrail-processor; then
    echo "✅ Service is running successfully!"
else
    echo "❌ Service failed to start. Checking logs..."
    sudo journalctl -u cloudtrail-processor -n 20 --no-pager
    exit 1
fi
echo ""

# Show recent logs
echo "📝 Recent logs from the processor:"
echo "-----------------------------------"
sudo journalctl -u cloudtrail-processor -n 10 --no-pager
echo ""

# Provide next steps
echo "==================================="
echo "✅ Update Complete!"
echo "==================================="
echo ""
echo "What happens next:"
echo "1. The processor will check for new CloudTrail logs every 5 minutes"
echo "2. New logs will have enhanced resource extraction"
echo "3. EC2 instances, S3 buckets, and other resources will now show correctly"
echo "4. CloudTrail's own bucket will be filtered out"
echo ""
echo "To monitor progress:"
echo "  sudo journalctl -u cloudtrail-processor -f"
echo ""
echo "To check processed logs:"
echo "  ls -lh /var/log/cloudtrail-processed/ | tail -10"
echo ""
echo "Expected wait time: 5-10 minutes for new events to appear in Grafana"
echo ""

# Optional: Ask if user wants to reprocess existing logs
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Optional: Reprocess last 24 hours of logs with new logic?"
echo "This will apply the fix to existing logs immediately."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Reprocess existing logs? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Deleting state file to trigger reprocessing..."
    sudo rm -f /var/lib/promtail/cloudtrail-state.json
    echo "✓ State file deleted"
    echo ""
    
    echo "🔄 Restarting processor to start reprocessing..."
    sudo systemctl restart cloudtrail-processor
    echo ""
    
    echo "✅ Reprocessing started!"
    echo "The processor will now re-download and process CloudTrail logs from the last 24 hours."
    echo "This may take 5-15 minutes depending on log volume."
    echo ""
    echo "Monitor progress with:"
    echo "  sudo journalctl -u cloudtrail-processor -f"
else
    echo "Skipped reprocessing. Only new events will use the improved resource extraction."
fi

echo ""
echo "🎉 All done! Check your Grafana dashboard in a few minutes."
