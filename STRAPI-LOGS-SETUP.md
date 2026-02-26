# Strapi Logs in Promtail & Grafana

Add Strapi (PM2) application logs to your Grafana dashboard.

## Prerequisites

- Strapi running under **PM2** on EC2
- PM2 logs at `~/.pm2/logs/` (e.g. `/home/ubuntu/.pm2/logs/strapi-out.log`)

## Quick setup

Run on the Strapi EC2:

```bash
cd cloudtrail-promtail-grafana-1
chmod +x setup-strapi-promtail.sh
./setup-strapi-promtail.sh
```

The script will:
1. Auto-detect PM2 log path
2. Optionally narrow to your Strapi app (e.g. `strapi*.log`)
3. Install Promtail if needed
4. Configure and start the Promtail service

## Manual setup

If you prefer to configure manually:

```bash
# Replace with your path and app name
STRAPI_PATH="/home/ubuntu/.pm2/logs/strapi*.log"
sed -i "s|STRAPI_LOG_PATH|$STRAPI_PATH|g; s/INSTANCE_ID/$(hostname)/" promtail-strapi-config.yaml
sudo cp promtail-strapi-config.yaml /etc/promtail/promtail-config.yaml
sudo systemctl restart promtail
```

## PM2 log paths

| OS / User   | Path                        |
|------------|-----------------------------|
| Ubuntu     | `/home/ubuntu/.pm2/logs/`   |
| Amazon Linux | `/home/ec2-user/.pm2/logs/` |
| Root       | `/root/.pm2/logs/`          |

Files: `<app-name>-out.log` (stdout/Pino) and `<app-name>-error.log` (stderr)

## Grafana

- **Explore** query: `{job="strapi"}`
- **App dropdown**: Strapi will appear once logs flow
- Strapi uses Pino JSON: `{"level":30,"msg":"..."}` – level 30=info, 50=error

## Troubleshooting

- **No logs**: Run `pm2 list` to confirm app name; use `strapi*.log` or `strapi-ceramic*.log` as glob
- **Promtail fails**: `sudo journalctl -u promtail -n 30`
- **Permissions**: `sudo chmod 644 ~/.pm2/logs/*.log`

### "No data" in Ceramic Home panel (ip-172-31-16-15)

The Ceramic panel shows data only when Promtail runs **on that specific EC2 instance**. Run this on **ip-172-31-16-15** (SSH to Ceramic Home server):

```bash
# 1. SSH to Ceramic Home EC2
ssh ubuntu@<CERAMIC-EC2-IP>

# 2. Ensure project is present (clone or scp if needed)
cd ~/cloudtrail-promtail-grafana-1
# If missing: git clone <repo> .  OR  scp -r ... from your machine

# 3. Run setup - when prompted enter: strapi-ceramic
chmod +x setup-strapi-promtail.sh
./setup-strapi-promtail.sh

# 4. Verify (hostname must be ip-172-31-16-15)
hostname
sudo systemctl status promtail
```

**Diagnostic script** – run `./troubleshoot-strapi-logs.sh` to check hostname, PM2, Promtail config.
