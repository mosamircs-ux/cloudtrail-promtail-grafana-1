# Alerting Setup - EC2 Status & Application Errors → Email

This guide configures Grafana to send email alerts when:
- **EC2 Down** – No logs from any EC2 in 15 minutes
- **Application Errors** – Errors detected in logs
- **High Error Rate** – 50+ errors in 5 minutes

---

## Overview

```
Loki (logs) → Grafana Alert Rules → Contact Point (Email) → Your Inbox
```

---

## Part 1: Configure SMTP (Email)

### Option A: Grafana in Docker

Add these environment variables when running Grafana:

```bash
-e GF_SMTP_ENABLED=true \
-e GF_SMTP_HOST=smtp.gmail.com:587 \
-e GF_SMTP_USER=your-email@gmail.com \
-e GF_SMTP_PASSWORD=your-app-password \
-e GF_SMTP_FROM_ADDRESS=your-email@gmail.com \
-e GF_SMTP_FROM_NAME="Grafana Alerts"
```

**Gmail:** Create an [App Password](https://support.google.com/accounts/answer/185833) (not your regular password).

**Docker Compose** – Add to your Grafana service:
```yaml
environment:
  GF_SMTP_ENABLED: "true"
  GF_SMTP_HOST: smtp.gmail.com:587
  GF_SMTP_USER: your-email@gmail.com
  GF_SMTP_PASSWORD: ${SMTP_PASSWORD}   # Use env file or export
  GF_SMTP_FROM_ADDRESS: your-email@gmail.com
  GF_SMTP_FROM_NAME: "Grafana Alerts"
```

### Option B: Grafana with config file

Edit `grafana.ini` (or `custom.ini`):

```ini
[smtp]
enabled = true
host = smtp.gmail.com:587
user = your-email@gmail.com
password = your-app-password
from_address = your-email@gmail.com
from_name = Grafana Alerts
```

Restart Grafana after changes.

---

## Part 2: Setup Alerting (Choose One Method)

### Method 1: Provisioning (Recommended)

1. **Get Loki datasource UID**
   - Grafana → **Connections** → **Data sources** → Click **Loki**
   - Copy the UID from the URL (e.g. `P1E6F4C4z`) or from the **Settings** tab

2. **Edit alert rules**
   ```bash
   # Replace LOKI_DATASOURCE_UID in the file
   sed -i 's/LOKI_DATASOURCE_UID/your-loki-uid/' provisioning/alerting/alert-rules.yaml
   ```

3. **Edit contact point** – Set your email in `provisioning/alerting/contact-points.yaml`:
   ```yaml
   addresses: "your-email@example.com"
   ```

4. **Mount provisioning in Grafana Docker**
   ```bash
   docker run -d \
     -v $(pwd)/provisioning:/etc/grafana/provisioning \
     -e GF_SMTP_ENABLED=true \
     -e GF_SMTP_HOST=smtp.gmail.com:587 \
     ... (other env vars) \
     grafana/grafana:latest
   ```

   Or add to existing docker-compose:
   ```yaml
   volumes:
     - ./provisioning:/etc/grafana/provisioning
   ```

5. **Restart Grafana**
   ```bash
   docker restart monitoring-grafana
   ```

---

### Method 2: Create Alerts via Grafana UI

If provisioning doesn't work, create alerts manually:

1. **Create Contact Point**
   - Grafana → **Alerting** → **Contact points** → **New contact point**
   - Name: `email-alerts`
   - Integration: **Email**
   - Addresses: your email
   - **Save**

2. **Create Alert Rules**

   **Rule 1: All EC2 Down**
   - **Alerting** → **Alert rules** → **New alert rule**
   - Name: `All EC2 Instances Down`
   - Query: Data source **Loki**, paste:
     ```
     count(count by (instance) (count_over_time({job=~".+"}[15m]) > 0))
     ```
   - Condition: **IS BELOW** `1` (or **IS EQUAL** `0`)
   - Evaluate every: `1m`, For: `5m`
   - Add notification: **email-alerts**
   - **Save**

   **Rule 2: Application Errors**
   - Name: `Application Errors Detected`
   - Query (Loki):
     ```
     sum(count_over_time({job=~".+"} |~ "(?i)(error|exception|fail|fatal|panic)"[5m]))
     ```
   - Condition: **IS ABOVE** `0`
   - Evaluate: `1m`, For: `1m`
   - Notification: **email-alerts**
   - **Save**

   **Rule 3: High Error Rate**
   - Name: `High Error Rate`
   - Same query as Rule 2
   - Condition: **IS ABOVE** `50`
   - Evaluate: `1m`, For: `2m`
   - Notification: **email-alerts**
   - **Save**

3. **Set Default Contact Point**
   - **Alerting** → **Notification policies**
   - Ensure default contact point is **email-alerts** (or add route matching your rules)

---

## Part 3: Add Per-Instance EC2 Down Alert (Optional)

To alert when a **specific EC2** stops sending logs, create a rule per instance:

- Query (replace `cloudtrail-processor` with your instance name):
  ```
  sum(count_over_time({instance="cloudtrail-processor"}[15m]))
  ```
- Condition: **IS BELOW** `1`
- For: `5m`

---

## Part 4: Verify

1. **Test contact point**
   - **Alerting** → **Contact points** → **email-alerts** → **Test**
   - You should receive a test email

2. **Check alert rules**
   - **Alerting** → **Alert rules**
   - Rules should show **Normal** when systems are healthy

3. **Simulate**
   - Stop Promtail on an EC2 → after 15 min, "All EC2 Down" should fire

---

## File Reference

| File | Purpose |
|------|---------|
| `provisioning/alerting/contact-points.yaml` | Email contact point |
| `provisioning/alerting/alert-rules.yaml` | EC2 & error alert rules |
| `provisioning/alerting/policies.yaml` | Route alerts to email |
| `grafana-smtp.ini` | SMTP config reference |
| `docker-compose.grafana.yaml` | Docker example |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No emails received | Check SMTP settings, test contact point, check spam |
| Alerts not firing | Verify Loki has data, check query in Explore |
| "No data" in alert | LogQL returns empty – ensure `instance` label exists in logs |
| Gmail blocking | Use App Password, enable "Less secure app access" if needed |
