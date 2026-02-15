#!/bin/bash
# Quick setup for Grafana alerting provisioning
# Run from project root

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Grafana Alerting Setup"
echo "=========================================="
echo ""

# Check provisioning files exist
if [ ! -f provisioning/alerting/contact-points.yaml ]; then
    echo -e "${RED}Error: provisioning/alerting/contact-points.yaml not found${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Enter your email for alerts:${NC}"
read -p "Email: " ALERT_EMAIL
if [ -z "$ALERT_EMAIL" ]; then
    echo -e "${RED}Email is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}2. Enter your Loki datasource UID (Grafana → Connections → Data sources → Loki → copy UID):${NC}"
read -p "Loki UID: " LOKI_UID
if [ -z "$LOKI_UID" ]; then
    echo -e "${YELLOW}Using placeholder - you must edit alert-rules.yaml manually${NC}"
    LOKI_UID="LOKI_DATASOURCE_UID"
fi

# Update contact point
echo ""
echo -e "${GREEN}Updating contact point with email: $ALERT_EMAIL${NC}"
sed -i.bak "s|addresses: \".*\"|addresses: \"$ALERT_EMAIL\"|" provisioning/alerting/contact-points.yaml

# Update alert rules
echo -e "${GREEN}Updating alert rules with Loki UID: $LOKI_UID${NC}"
sed -i.bak "s/LOKI_DATASOURCE_UID/$LOKI_UID/g" provisioning/alerting/alert-rules.yaml

# Cleanup backups (Unix)
if command -v sed &>/dev/null; then
    rm -f provisioning/alerting/contact-points.yaml.bak provisioning/alerting/alert-rules.yaml.bak 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure SMTP in Grafana (see ALERTING-SETUP.md)"
echo "2. Mount provisioning in Grafana: -v $(pwd)/provisioning:/etc/grafana/provisioning"
echo "3. Restart Grafana"
echo ""
