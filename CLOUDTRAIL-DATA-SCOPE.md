# Getting ALL Access Keys, Users & Resources in CloudTrail

If your dashboard only shows **your** IAM user and access key (not all account activity), follow this guide.

---

## Causes & Fixes

### 1. Limited Data Processed (Most Common)

**Cause:** On first run, the processor only fetched the last **24 hours** of logs. If only you were active then, you'll only see your data.

**Fix:** Run a full backfill:

```bash
# On the CloudTrail processor EC2
cd ~/cloudtrail-promtail-grafana-1
chmod +x backfill-cloudtrail.sh
./backfill-cloudtrail.sh
```

This clears state and reprocesses the last **90 days** from S3. You’ll see all users, keys, and resources.

### 2. Extend Initial Lookback

**Cause:** Not enough history loaded for your first run.

**Fix:** Edit `config.yaml`:

```yaml
initial_lookback_days: 30   # or 90 for full quarter
```

Then clear state and restart:

```bash
echo '{"last_processed_time": null, "processed_files": []}' | sudo tee /var/lib/promtail/cloudtrail-state.json
sudo systemctl restart cloudtrail-processor
```

### 3. CloudTrail Trail Configuration (AWS Console)

**Cause:** The trail may be limited to certain events or resources.

**Check and update in AWS Console:**

1. **CloudTrail** → **Trails** → your trail
2. **Edit** → **Event selectors**
3. Ensure:
   - **Management events** – All (or at least Read + Write)
   - **Data events** (optional) – Add S3/Lambda if needed
   - **Scope** – Entire account, not specific resources
4. **Apply** and wait ~15 minutes for new delivery.

### 4. S3 Prefix Correct

**Cause:** Prefix may be wrong for your bucket layout.

**Verify:** Standard layout is:
```
AWSLogs/123456789012/CloudTrail/region/YYYY/MM/DD/xxx.json.gz
```

`config.yaml` should have:

```yaml
s3_prefix: AWSLogs/
```

Run the diagnostic:

```bash
python3 diagnose-cloudtrail-s3.py
```

This shows which users and keys are in the raw S3 logs.

---

## Quick Checklist

| Step | Action |
|------|--------|
| 1 | Run `./backfill-cloudtrail.sh` |
| 2 | Run `python3 diagnose-cloudtrail-s3.py` to inspect raw data |
| 3 | Wait 10–15 min for processor to finish |
| 4 | Refresh Grafana; widen the time range (e.g. 24h → 7d) |

---

## After Backfill

- **CloudTrail dashboard** – Use “All” for Access Key and Event filters.
- **Time range** – Use at least “Last 7 days” to see backfilled data.
- **Loki retention** – If Loki keeps logs for < 7 days, older events will disappear after retention.
