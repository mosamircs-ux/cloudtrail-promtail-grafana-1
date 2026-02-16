#!/usr/bin/env python3
"""
Find CloudTrail events that have errorCode/errorMessage in S3.
Run this to verify if your account has any API failures - if none are found,
Error Code/Message will always be empty in Grafana (expected).
"""
import json
import gzip
import sys
from datetime import datetime

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
        except Exception as e:
            print(f"Config error: {e}. Using defaults.")
            break
    return {
        'aws': {
            's3_bucket': 'aws-cloudtrail-logs-124737196430-56a3b94b',
            's3_prefix': 'AWSLogs/',
            'region': 'me-south-1'
        }
    }


def has_error(evt):
    """Check if event has errorCode or errorMessage."""
    if not isinstance(evt, dict):
        return False
    ec = evt.get('errorCode') or evt.get('error_code')
    em = evt.get('errorMessage') or evt.get('error_message')
    return bool(ec or em)


def extract_events(data):
    """Flatten CloudTrail records from various formats."""
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
                out.extend(evt for evt in rec['events'] if isinstance(evt, dict))
            elif 'eventList' in rec and isinstance(rec['eventList'], list):
                out.extend(evt for evt in rec['eventList'] if isinstance(evt, dict))
            elif 'userIdentity' in rec or 'eventSource' in rec or 'eventName' in rec:
                out.append(rec)
        elif isinstance(rec, list):
            for sub in rec:
                if isinstance(sub, dict):
                    out.append(sub)
    return out


def main():
    config = load_config()
    bucket = config['aws']['s3_bucket']
    prefix = config['aws']['s3_prefix']
    region = config['aws'].get('region', 'us-east-1')

    print("\n=== CloudTrail Error Events Diagnostic ===\n")
    print(f"Bucket: {bucket}, Prefix: {prefix}\n")

    s3 = boto3.client('s3', region_name=region)

    # List log files (standard CloudTrail first - more likely to have errors)
    log_files = []
    try:
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            for obj in page.get('Contents', []):
                key = obj['Key']
                if key.endswith('.json.gz') and 'Digest' not in key and obj['Size'] > 100:
                    # Prefer standard CloudTrail over aggregated
                    if 'CloudTrail-Aggregated' not in key and '/CloudTrail/' in key:
                        log_files.insert(0, {'key': key, 'size': obj['Size']})
                    else:
                        log_files.append({'key': key, 'size': obj['Size']})
    except ClientError as e:
        err = e.response.get('Error', {}).get('Code', '')
        if err == 'InvalidAccessKeyId':
            print("ERROR: Invalid AWS credentials. Run 'aws configure' or use EC2 IAM role.")
        else:
            print(f"ERROR: {e}")
        sys.exit(1)

    if not log_files:
        print("No CloudTrail log files found.")
        sys.exit(1)

    # Scan up to 50 most recent files for error events
    files_to_scan = log_files[:50]
    error_events = []
    total_events = 0

    print(f"Scanning {len(files_to_scan)} log files for error events...\n")

    for fi in files_to_scan:
        try:
            resp = s3.get_object(Bucket=bucket, Key=fi['key'])
            with gzip.GzipFile(fileobj=resp['Body']) as f:
                data = json.load(f)

            events = extract_events(data)
            total_events += len(events)

            for evt in events:
                if has_error(evt):
                    error_events.append({
                        'file': fi['key'],
                        'event': evt
                    })
        except Exception as e:
            print(f"  Error reading {fi['key']}: {e}")

    # Report
    print(f"Scanned ~{total_events} events across {len(files_to_scan)} files.\n")

    if not error_events:
        print("No error events found in the scanned files.")
        print("\nThis means:")
        print("  - Your AWS API calls are succeeding (no failures in the sample)")
        print("  - Error Code and Error Message will be empty in Grafana (expected)")
        print("\nTo see error messages in Grafana, you need actual API failures.")
        print("You can test by: running an AWS CLI command that fails (e.g. wrong region, wrong resource ID)")
        print("\nTo scan more files, edit this script and increase the file limit.")
        print("")
        sys.exit(0)

    print(f"Found {len(error_events)} event(s) with errorCode/errorMessage:\n")

    for i, item in enumerate(error_events[:20]):  # Show up to 20
        evt = item['event']
        ec = evt.get('errorCode') or evt.get('error_code') or '(none)'
        em = evt.get('errorMessage') or evt.get('error_message') or '(none)'
        name = evt.get('eventName', 'Unknown')
        src = evt.get('eventSource', 'Unknown')
        ts = evt.get('eventTime', 'Unknown')
        print(f"  {i+1}. [{ts}] {name} ({src})")
        print(f"     Error Code: {ec}")
        print(f"     Error Message: {em}")
        print()

    if len(error_events) > 20:
        print(f"  ... and {len(error_events) - 20} more.\n")

    print("If these events exist in S3 but Grafana shows empty Error Code/Message:")
    print("  1. Re-run the CloudTrail processor to reprocess files:")
    print("     python3 cloudtrail_processor.py  (or restart the service)")
    print("  2. Run backfill-cloudtrail.sh to reload historical data")
    print("  3. Ensure Promtail is tailing /var/log/cloudtrail-processed/")
    print("")


if __name__ == '__main__':
    main()
