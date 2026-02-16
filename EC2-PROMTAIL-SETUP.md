# Install Promtail on Each EC2 - Step by Step

Run these steps **on each EC2** (except the one that already runs the CloudTrail processor).

---

## Option 1: One-Command Install (Recommended)

### 1. Copy files to the EC2

```bash
# From your laptop (replace with your EC2 IP or hostname)
scp -r cloudtrail-promtail-grafana-1 ubuntu@<EC2-IP>:~/

# Or clone the repo on the EC2
ssh ubuntu@<EC2-IP>
git clone <your-repo-url> cloudtrail-promtail-grafana-1
cd cloudtrail-promtail-grafana-1
```

### 2. Edit Loki URL (if different from 16.24.169.121)

```bash
nano install-promtail-on-ec2.sh
# Change LOKI_URL="http://16.24.169.121:3100/loki/api/v1/push" to your Loki IP
```

### 3. Run the install script

```bash
chmod +x install-promtail-on-ec2.sh
./install-promtail-on-ec2.sh
```

### 4. Verify

```bash
sudo systemctl status promtail
# Should show: active (running)
```

---

## Option 2: Manual Install

If the script doesn't work, do it manually:

### 1. Install Promtail

```bash
cd /tmp
curl -sL -O "https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip"
unzip -q promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail
```

### 2. Create config

```bash
sudo mkdir -p /etc/promtail
```

Create `/etc/promtail/promtail-config.yaml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://16.24.169.121:3100/loki/api/v1/push

scrape_configs:
  - job_name: syslog
    static_configs:
      - targets: [localhost]
        labels:
          job: syslog
          instance: $(hostname)
        __path__: /var/log/syslog
    pipeline_stages: []
```

**Amazon Linux:** Change `__path__: /var/log/syslog` to `__path__: /var/log/messages`  
**Instance label:** Replace `$(hostname)` with the actual output of `hostname` or a friendly name like `web-server-1`

### 3. Run Promtail

```bash
# Test run
/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml

# Or as systemd service
sudo tee /etc/systemd/system/promtail.service << 'EOF'
[Unit]
Description=Promtail
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now promtail
```

---

## Repeat for Every EC2

Do this on **each** of your EC2 instances. Each one will show up in the Main dashboard within a few minutes.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Promtail won't start | Check `/var/log/syslog` vs `/var/log/messages` exists for your OS. Edit config to use the correct path. |
| No logs in Loki | Ensure Loki IP is correct and reachable from the EC2 (security group allows outbound to Loki port 3100). |
| Wrong instance name | Edit config, change `instance: ` label to a friendly name. |
| Port 9080 in use | Change `http_listen_port` in the config. |
