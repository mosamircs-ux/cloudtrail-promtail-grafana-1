#!/usr/bin/env python3
"""
Diagnose CloudTrail S3 bucket - see what users, keys, and resources exist in the raw data.
Run this to verify you have data from ALL account activity, not just your user.
"""
import json
import gzip
import sys
from collections import Counter, defaultdict
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
        'aws': {'s3_bucket': 'aws-cloudtrail-logs-124737196430-56a3b94b', 's3_prefix': 'AWSLogs/', 'region': 'me-south-1'}
    }

def main():
    config = load_config()
    bucket = config['aws']['s3_bucket']
    prefix = config['aws']['s3_prefix']
    region = config['aws'].get('region', 'us-east-1')

    print(f"\n=== CloudTrail S3 Diagnostic ===\n")
    print(f"Bucket: {bucket}")
    print(f"Prefix: {prefix}")
    print(f"Region: {region}\n")

    s3 = boto3.client('s3', region_name=region)

    # List and sample files
    print("Listing log files...")
    try:
        s3.head_bucket(Bucket=bucket)
    except ClientError as e:
        err = e.response.get('Error', {}).get('Code', '')
        if err == 'InvalidAccessKeyId':
            print("\nERROR: Invalid AWS Access Key - the key does not exist or was deleted.")
            print("Fix: 1) Use EC2 IAM role (recommended) 2) Run 'aws configure' with valid keys")
        elif err == '403':
            print("\nERROR: Access denied to S3 bucket. Check IAM permissions.")
        else:
            print(f"\nERROR: {e}")
        sys.exit(1)

    paginator = s3.get_paginator('list_objects_v2')
    log_files = []
    try:
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            for obj in page.get('Contents', []):
                key = obj['Key']
                if key.endswith('.json.gz') and 'Digest' not in key and obj['Size'] > 100:
                    log_files.append({'key': key, 'size': obj['Size'], 'modified': obj['LastModified']})
    except ClientError as e:
        err = e.response.get('Error', {}).get('Code', '')
        if err == 'InvalidAccessKeyId':
            print("\nERROR: Invalid AWS Access Key - the key does not exist or was deleted.")
            print("Fix: 1) Use EC2 IAM role (recommended) 2) Run 'aws configure' with valid keys")
        elif err == '403':
            print("\nERROR: Access denied. Check IAM permissions for s3:ListBucket.")
        else:
            print(f"\nERROR: {e}")
        sys.exit(1)

    print(f"Found {len(log_files)} log files\n")

    if not log_files:
        print("ERROR: No log files found!")
        print("Check: 1) S3 bucket name 2) Prefix (try AWSLogs/) 3) IAM permissions")
        sys.exit(1)

    # Sample up to 20 files to analyze
    users = Counter()
    access_keys = Counter()
    event_sources = Counter()
    event_names = Counter()
    resources = defaultdict(int)
    total_events = 0

    # Sample from both CloudTrail and CloudTrail-Aggregated (different formats)
    cloudtrail_std = [f for f in log_files if '/CloudTrail/' in f['key'] and 'CloudTrail-Aggregated' not in f['key']]
    cloudtrail_agg = [f for f in log_files if 'CloudTrail-Aggregated' in f['key']]
    files_to_check = (cloudtrail_std[:10] if cloudtrail_std else []) + (cloudtrail_agg[:10] if cloudtrail_agg else [])
    if not files_to_check:
        files_to_check = log_files[:20]
    sample_size = len(files_to_check)

    print(f"Analyzing {sample_size} files ({len(cloudtrail_std[:10])} standard, {len(cloudtrail_agg[:10])} aggregated)...\n")

    for fi in files_to_check:
        try:
            resp = s3.get_object(Bucket=bucket, Key=fi['key'])
            with gzip.GzipFile(fileobj=resp['Body']) as f:
                data = json.load(f)

            # Handle both formats: {"Records": [...]} and [...]
            if isinstance(data, list):
                records = data
            elif isinstance(data, dict):
                records = data.get('Records', [])
            else:
                continue
            if not isinstance(records, list):
                continue

            total_events += len(records)

            def process_event(rec):
                """Process a single event record (dict)."""
                if not isinstance(rec, dict):
                    return
                ui = rec.get('userIdentity') or {}
                if not isinstance(ui, dict):
                    ui = {}
                user_type = ui.get('type', 'Unknown')
                arn_val = ui.get('arn', '') or ''
                user_name = ui.get('userName', '') or (arn_val.split('/')[-1] if isinstance(arn_val, str) and '/' in arn_val else '')
                princ = ui.get('principalId', '') or ''
                ak = ui.get('accessKeyId', '') or ''

                if user_name:
                    users[user_name] += 1
                elif princ:
                    users[str(princ)[:50]] += 1
                else:
                    users[f"{user_type}:{str(princ)[:20]}"] += 1

                if ak:
                    access_keys[ak] += 1

                event_sources[rec.get('eventSource', 'Unknown')] += 1
                event_names[rec.get('eventName', 'Unknown')] += 1

                for r in (rec.get('resources') or []):
                    if isinstance(r, dict):
                        arn = r.get('ARN', '') or r.get('arn', '')
                    elif isinstance(r, str):
                        arn = r
                    else:
                        continue
                    if arn:
                        resources[str(arn).split(':')[-1].split('/')[0][:50]] += 1

            for rec in records:
                if isinstance(rec, list):
                    for sub in rec:
                        process_event(sub) if isinstance(sub, dict) else None
                elif isinstance(rec, dict):
                    # CloudTrail-Aggregated may have events/eventList nested
                    if 'events' in rec and isinstance(rec['events'], list):
                        for evt in rec['events']:
                            process_event(evt) if isinstance(evt, dict) else None
                    elif 'eventList' in rec and isinstance(rec['eventList'], list):
                        for evt in rec['eventList']:
                            process_event(evt) if isinstance(evt, dict) else None
                    else:
                        process_event(rec)

        except Exception as e:
            print(f"  Error reading {fi['key']}: {e}")

    # If all aggregated and 0 events, show sample structure
    if total_events == 0 and cloudtrail_agg:
        print("\n  Could not parse aggregated format. Sample structure from first file:")
        try:
            resp = s3.get_object(Bucket=bucket, Key=cloudtrail_agg[0]['key'])
            with gzip.GzipFile(fileobj=resp['Body']) as f:
                sample = json.load(f)
            print(f"  Top-level keys: {list(sample.keys()) if isinstance(sample, dict) else 'list'}")
            if isinstance(sample, dict) and 'Records' in sample and sample['Records']:
                r0 = sample['Records'][0]
                print(f"  First record keys: {list(r0.keys()) if isinstance(r0, dict) else type(r0)}")
        except Exception as e:
            print(f"  (Could not sample: {e})")

    print("\n--- Results ---\n")
    print(f"Total events in sample: {total_events}")
    print(f"Unique users/identities: {len(users)}")
    print(f"Unique access keys: {len(access_keys)}\n")

    print("Top 15 users/identities:")
    for u, c in users.most_common(15):
        print(f"  {u}: {c}")

    print("\nAccess keys seen:")
    for ak, c in access_keys.most_common(15):
        print(f"  {ak}: {c}")

    print("\nTop event sources:")
    for s, c in event_sources.most_common(10):
        print(f"  {s}: {c}")

    if len(users) <= 2 and len(access_keys) <= 2:
        print("\n⚠️  WARNING: Very few users/keys in sample. Possible causes:")
        print("  1. CloudTrail trail may log only specific resources/users")
        print("  2. Most account activity is from one user (you)")
        print("  3. Run backfill-cloudtrail.sh to load more historical data")
        print("  4. Check AWS Console: CloudTrail → Trails → Event history scope")
    else:
        print("\n✓ Multiple users/keys found - data looks good.")

    print("\nTo load ALL historical data, run: ./backfill-cloudtrail.sh")
    print("")

if __name__ == '__main__':
    main()
