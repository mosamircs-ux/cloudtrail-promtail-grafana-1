# Fix: New EC2s Not Showing in Grafana

If you installed Promtail on new EC2s but they don't appear in the Main dashboard, work through this checklist.

---

## Step 1: Run Troubleshooter on Each New EC2

```bash
cd ~/cloudtrail-promtail-grafana-1
chmod +x troubleshoot-promtail-loki.sh
./troubleshoot-promtail-loki.sh
```

This checks: Promtail running, Loki reachable, config correct.

---

## Step 2: Fix Loki Connection (Most Common Issue)

### A. Security group on Loki/Grafana EC2 (16.24.169.121)

Port **3100** must accept incoming traffic:

1. AWS Console → EC2 → Security Groups
2. Select the group for 16.24.169.121
3. Inbound rules: add **Custom TCP 3100**, Source = your VPC CIDR (e.g. `172.31.0.0/16`) or the specific EC2 IPs
4. Save

### B. Loki inside Docker must listen on all interfaces

If Loki listens only on localhost, other EC2s can’t connect.

Check Loki run command:
```bash
docker inspect monitoring-loki | grep -A5 "PortBindings"
```

Loki should expose `0.0.0.0:3100`. Example run:
```bash
docker run -d -p 0.0.0.0:3100:3100 grafana/loki:3.0.0 ...
```

If you use docker-compose, ensure:
```yaml
ports:
  - "0.0.0.0:3100:3100"
```

### C. Test from a new EC2

```bash
# From a NEW EC2 (replace with your Loki EC2 IP)
curl http://16.24.169.121:3100/ready
# Should return: ready
```

If this fails, the problem is network/connectivity.

---

## Step 3: Verify Promtail Sends Logs

On each new EC2:

```bash
# Is Promtail running?
sudo systemctl status promtail

# Recent logs
sudo journalctl -u promtail -n 20 --no-pager

# Config (instance label and Loki URL)
cat /etc/promtail/promtail-config.yaml | grep -E "instance:|url:"
```

- `instance:` should be set (hostname or custom name)
- `url:` must point to Loki, e.g. `http://16.24.169.121:3100/loki/api/v1/push`

---

## Step 4: Verify Loki Receives Logs

On the **Loki/Grafana EC2** (16.24.169.121):

```bash
# Query Loki for any logs with instance label
curl -s -G "http://localhost:3100/loki/api/v1/label/instance/values"
```

You should see `instance` values like `cloudtrail-processor`, `ip-172-31-10-39`, etc.

Or in **Grafana Explore**:
- Data source: Loki
- Query: `{job=~".+"}` 
- Check for multiple `instance` values in the labels

---

## Step 5: Grafana Datasource

- Grafana → Connections → Data sources → Loki
- URL: `http://localhost:3100` (or `http://16.24.169.121:3100` if Grafana runs elsewhere)
- Save & test

---

## Step 6: Re-run Install on New EC2s

If anything was wrong (Loki URL, instance label, config path):

```bash
# On each new EC2
cd ~/cloudtrail-promtail-grafana-1

# Set Loki IP if different
export LOKI_IP=16.24.169.121

# Edit script if needed
nano install-promtail-on-ec2.sh   # Change LOKI_URL

# Re-run
./install-promtail-on-ec2.sh

# Restart
sudo systemctl restart promtail
```

---

## Quick Checklist

| Check | How to verify |
|-------|----------------|
| Loki port 3100 open | Security group allows inbound 3100 from your VPC |
| Loki reachable | `curl http://16.24.169.121:3100/ready` from new EC2 |
| Promtail running | `systemctl status promtail` |
| Config correct | `instance` and `url` in `/etc/promtail/promtail-config.yaml` |
| Log file exists | `/var/log/syslog` (Ubuntu) or `/var/log/messages` (Amazon Linux) |
| Loki has data | Grafana Explore: `{job=~".+"}` shows multiple instances |

---

## If Still Not Working

1. Run `./troubleshoot-promtail-loki.sh` on a new EC2 and share the output
2. From the new EC2: `curl -v http://16.24.169.121:3100/ready` (check for connection errors)
3. On Loki host: `docker logs monitoring-loki` (check for incoming push errors)
