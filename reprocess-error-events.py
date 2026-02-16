#!/usr/bin/env python3
"""
Reprocess S3 CloudTrail files that contain error events, so they appear in Grafana
with Error Code and Error Message populated.

Run on the EC2 where the CloudTrail processor runs. Requires sudo to write state.
"""
import json
import gzip
import sys
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("Install boto3: pip install boto3")
    sys.exit(1)


def load_config(config_path=None):
    paths = [config_path, '/opt/cloudtrail-processor/config.yaml', 'config.yaml']
    for p in paths:
        if not p:
            continue
        try:
            import yaml
            with open(p) as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            continue
        except Exception:
            break
    return {'aws': {'s3_bucket': 'aws-cloudtrail-logs-124737196430-56a3b94b', 's3_prefix': 'AWSLogs/', 'region': 'us-east-1'}}


def has_error(evt):
    if not isinstance(evt, dict):
        return False
    return bool(evt.get('errorCode') or evt.get('error_code') or evt.get('errorMessage') or evt.get('error_message'))


def extract_events(data):
    if isinstance(data, list):
        records = data
    elif isinstance(data, dict):
        records = data.get('Records', [])
    else:
        return []
    out = []
    for rec in records:
        if isinstance(rec, dict):
            if 'events' in rec and isinstance(rec['events'], list):
                out.extend(e for e in rec['events'] if isinstance(e, dict))
            elif 'eventList' in rec and isinstance(rec['eventList'], list):
                out.extend(e for e in rec['eventList'] if isinstance(e, dict))
            elif 'userIdentity' in rec or 'eventSource' in rec or 'eventName' in rec:
                out.append(rec)
        elif isinstance(rec, list):
            for sub in rec:
                if isinstance(sub, dict):
                    out.append(sub)
    return out


STATE_PATH = Path('/var/lib/promtail/cloudtrail-state.json')


def get_files_with_errors(config):
    """Return set of S3 keys that contain error events."""
    bucket = config['aws']['s3_bucket']
    prefix = config['aws']['s3_prefix']
    region = config['aws'].get('region', 'us-east-1')

    s3 = boto3.client('s3', region_name=region)

    log_files = []
    for page in s3.get_paginator('list_objects_v2').paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get('Contents', []):
            key = obj['Key']
            if key.endswith('.json.gz') and 'Digest' not in key and obj['Size'] > 100:
                if 'CloudTrail-Aggregated' not in key and '/CloudTrail/' in key:
                    log_files.insert(0, {'key': key, 'size': obj['Size']})
                else:
                    log_files.append({'key': key, 'size': obj['Size']})

    files_with_errors = set()
    for fi in log_files[:100]:  # Scan up to 100 files
        try:
            resp = s3.get_object(Bucket=bucket, Key=fi['key'])
            with gzip.GzipFile(fileobj=resp['Body']) as f:
                data = json.load(f)
            for evt in extract_events(data):
                if has_error(evt):
                    files_with_errors.add(fi['key'])
                    break
        except Exception:
            pass
    return files_with_errors


def main():
    config = load_config()
    state_path = Path(config.get('state_file', str(STATE_PATH)))

    print("\n=== Reprocess Error Events ===\n")

    # Find files with errors
    print("Scanning S3 for files with error events...")
    files_with_errors = get_files_with_errors(config)
    if not files_with_errors:
        print("No files with error events found.")
        sys.exit(0)

    print(f"Found {len(files_with_errors)} file(s) containing error events\n")

    # Load state
    if not state_path.exists():
        print(f"State file not found: {state_path}")
        print("Run the processor once first, or use backfill-cloudtrail.sh")
        sys.exit(1)

    try:
        with open(state_path) as f:
            state = json.load(f)
    except Exception as e:
        print(f"Error reading state: {e}")
        sys.exit(1)

    processed = set(state.get('processed_files', []))
    removed = files_with_errors & processed
    state['processed_files'] = [f for f in state['processed_files'] if f not in files_with_errors]

    if not removed:
        print("Error files are not in processed_files - they may not have been processed yet.")
        print("Try running backfill-cloudtrail.sh to load all data.")
        sys.exit(0)

    # Set last_processed_time old so those files pass the LastModified check
    state['last_processed_time'] = '2000-01-01T00:00:00'

    # Write state (may need sudo)
    try:
        with open(state_path, 'w') as f:
            json.dump(state, f, indent=2)
    except PermissionError:
        print(f"\nNeed sudo to write {state_path}. Run:")
        print(f"  sudo python3 {__file__}")
        sys.exit(1)

    print(f"Removed {len(removed)} file(s) from processed state.")
    print("\nNext: Restart the CloudTrail processor so it reprocesses these files:")
    print("  sudo systemctl restart cloudtrail-processor")
    print("\nThen expand Grafana time range to 'Last 7 days' or 'Last 30 days'")
    print("and check the 'CloudTrail Failures Only' panel.\n")


if __name__ == '__main__':
    main()
