# Laravel Logs in Promtail & Grafana

Add Laravel application logs to your Grafana dashboard.

## Step 1: Set Laravel log path

Laravel logs are usually in:

- **Single file:** `storage/logs/laravel.log`
- **Daily rotation:** `storage/logs/laravel-YYYY-MM-DD.log`

Use the directory containing these files as the path.

## Step 2: Add Laravel to Promtail on the Laravel EC2

### Option A: Using promtail-ec2-config.yaml (EC2 has other services too)

Edit `promtail-ec2-config.yaml`:

```yaml
# Replace LARAVEL_LOG_PATH with your actual path, e.g.:
__path__: /var/www/html/storage/logs/*.log
```

Then run:

```bash
cd ~/cloudtrail-promtail-grafana-1
sed -i "s|LARAVEL_LOG_PATH|/var/www/html/storage/logs|g; s/INSTANCE_ID/$(hostname)/" promtail-ec2-config.yaml
sudo cp promtail-ec2-config.yaml /etc/promtail/promtail-config.yaml
sudo systemctl restart promtail
```

### Option B: Using promtail-laravel-config.yaml (Laravel-only server)

```bash
cd ~/cloudtrail-promtail-grafana-1
sed -i "s|LARAVEL_LOG_PATH|/var/www/html/storage/logs|g; s/INSTANCE_ID/$(hostname)/" promtail-laravel-config.yaml
sudo cp promtail-laravel-config.yaml /etc/promtail/promtail-config.yaml
sudo systemctl restart promtail
```

## Step 3: Permissions

Ensure Promtail can read the logs:

```bash
# If Laravel runs as www-data (typical LAMP)
sudo usermod -aG www-data promtail   # or the user Promtail runs as

# Or make logs readable
sudo chmod 755 /var/www/html/storage
sudo chmod 644 /var/www/html/storage/logs/*.log
```

## Step 4: Grafana dashboard

The **Laravel Logs** table is in the Main dashboard. It shows:

- **Time** – log timestamp  
- **Level** – ERROR, WARNING, INFO, DEBUG (with colors)  
- **Env** – environment (production, local, etc.)  
- **Message** – log content  

Refresh or re-import the dashboard JSON to see it.

## Laravel log format

Default format: `[2024-02-16 08:30:45] production.ERROR: message`

Supported:

- Single: `storage/logs/laravel.log`
- Daily: `storage/logs/laravel-2024-02-16.log`

## Troubleshooting

**No logs in the table**

1. Confirm Promtail is running: `sudo systemctl status promtail`
2. Check paths and permissions: `ls -la /var/www/html/storage/logs/`
3. Generate test logs:
   ```php
   \Log::info('Test from Grafana');
   \Log::error('Test error');
   ```
4. In Grafana, use Explore → `{job="laravel"}` to inspect raw logs

**Logs not parsing**

If the table shows raw lines in a single column, your format may differ. Laravel config with `log_channel` and JSON formatting is supported; if you use a custom format, adjust the regex in the panel.
