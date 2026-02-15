#!/usr/bin/env python3
"""
CloudTrail S3 Log Processor - Enhanced Version
Downloads CloudTrail logs from S3, parses them, and writes formatted logs for Promtail
with enhanced access key and resource tracking
"""

import json
import gzip
import os
import time
import logging
from datetime import datetime, timedelta
from pathlib import Path
import boto3
from botocore.exceptions import ClientError
import yaml

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CloudTrailProcessor:
    def __init__(self, config_path='/opt/cloudtrail-processor/config.yaml'):
        """Initialize the CloudTrail processor"""
        self.config = self.load_config(config_path)
        self.s3_client = boto3.client('s3', region_name=self.config['aws']['region'])
        self.state_file = Path(self.config['state_file'])
        self.output_dir = Path(self.config['output_dir'])
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def load_config(self, config_path):
        """Load configuration from YAML file"""
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def load_state(self):
        """Load processing state to track last processed file"""
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                return json.load(f)
        return {'last_processed_time': None, 'processed_files': []}
    
    def save_state(self, state):
        """Save processing state"""
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)
    
    def list_new_logs(self, state):
        """List new CloudTrail log files from S3"""
        bucket = self.config['aws']['s3_bucket']
        prefix = self.config['aws']['s3_prefix']
        
        # Calculate time range
        if state['last_processed_time']:
            start_time = datetime.fromisoformat(state['last_processed_time'])
        else:
            # First run - get logs from last 24 hours
            start_time = datetime.utcnow() - timedelta(hours=24)
        
        logger.info(f"Looking for logs since {start_time}")
        
        new_files = []
        try:
            paginator = self.s3_client.get_paginator('list_objects_v2')
            pages = paginator.paginate(Bucket=bucket, Prefix=prefix)
            
            for page in pages:
                if 'Contents' not in page:
                    continue
                    
                for obj in page['Contents']:
                    key = obj['Key']
                    
                    # Skip CloudTrail Digest files (they're for validation, not logs)
                    if 'Digest' in key or 'digest' in key:
                        continue
                    
                    # CloudTrail log files end with .json.gz
                    if not key.endswith('.json.gz'):
                        continue
                    
                    # Skip files smaller than 100 bytes (likely empty or corrupted)
                    if obj['Size'] < 100:
                        continue
                    
                    # Check if already processed
                    if key in state['processed_files']:
                        continue
                    
                    # Check modification time
                    if obj['LastModified'].replace(tzinfo=None) > start_time:
                        new_files.append({
                            'key': key,
                            'size': obj['Size'],
                            'modified': obj['LastModified'].isoformat()
                        })
            
            logger.info(f"Found {len(new_files)} new log files")
            return new_files
            
        except ClientError as e:
            logger.error(f"Error listing S3 objects: {e}")
            return []
    
    def download_and_parse_log(self, s3_key):
        """Download and parse a CloudTrail log file"""
        bucket = self.config['aws']['s3_bucket']
        
        try:
            # Download file
            logger.info(f"Downloading {s3_key}")
            response = self.s3_client.get_object(Bucket=bucket, Key=s3_key)
            
            # Decompress gzip
            with gzip.GzipFile(fileobj=response['Body']) as gzipfile:
                content = gzipfile.read()
            
            # Parse JSON
            data = json.loads(content)
            return data.get('Records', [])
            
        except Exception as e:
            logger.error(f"Error processing {s3_key}: {e}")
            return []
    
    def extract_access_key_identifier(self, user_identity):
        """
        Extract meaningful access key identifier from user identity
        Returns actual access key or descriptive identifier
        """
        user_type = user_identity.get('type', 'Unknown')
        arn = user_identity.get('arn', '')
        access_key_id = user_identity.get('accessKeyId')
        
        # If access key exists, use it
        if access_key_id:
            return access_key_id
        
        # AssumedRole - extract role name
        if user_type == 'AssumedRole':
            if 'assumed-role' in arn:
                parts = arn.split('/')
                if len(parts) >= 2:
                    role_name = parts[-2]
                    return f"AssumedRole:{role_name}"
            return "AssumedRole:Unknown"
        
        # IAM User - likely console login
        if user_type == 'IAMUser':
            if '/' in arn:
                username = arn.split('/')[-1]
                return f"Console:{username}"
            return "Console:Unknown"
        
        # Root Account
        if user_type == 'Root':
            return "RootAccount"
        
        # AWS Service
        if user_type == 'AWSService':
            invoked_by = user_identity.get('invokedBy', 'unknown')
            return f"Service:{invoked_by}"
        
        # Federated User
        if user_type == 'FederatedUser':
            if '/' in arn:
                federated_user = arn.split('/')[-1]
                return f"Federated:{federated_user}"
            return "Federated:Unknown"
        
        # SAML User
        if user_type == 'SAMLUser':
            principal_id = user_identity.get('principalId', 'Unknown')
            return f"SAML:{principal_id}"
        
        # Unknown type
        return f"{user_type}:Unknown"
    
    def extract_resource_names(self, event):
        """
        Enhanced resource extraction from CloudTrail event
        Returns meaningful resource identifiers or operation type
        """
        event_name = event.get('eventName', '')
        event_source = event.get('eventSource', '')
        resources = event.get('resources', [])
        request_params = event.get('requestParameters', {})
        
        # Try to extract from resources array first
        if resources and isinstance(resources, list) and len(resources) > 0:
            resource_list = []
            for r in resources:
                if isinstance(r, dict):
                    arn = r.get('ARN', '')
                    if arn:
                        # Extract instance ID from EC2 ARN
                        if 'instance/' in arn:
                            instance_id = arn.split('instance/')[-1]
                            resource_list.append(instance_id)
                        # Extract bucket name from S3 ARN
                        elif 'arn:aws:s3:::' in arn:
                            bucket_name = arn.replace('arn:aws:s3:::', '').split('/')[0]
                            resource_list.append(bucket_name)
                        # Extract DB identifier from RDS ARN
                        elif ':db:' in arn:
                            db_id = arn.split(':db:')[-1]
                            resource_list.append(db_id)
                        # Extract function name from Lambda ARN
                        elif ':function:' in arn:
                            func_name = arn.split(':function:')[-1].split(':')[0]
                            resource_list.append(func_name)
                        # Extract volume ID from EBS ARN
                        elif 'volume/' in arn:
                            volume_id = arn.split('volume/')[-1]
                            resource_list.append(volume_id)
                        # Extract security group ID
                        elif 'security-group/' in arn:
                            sg_id = arn.split('security-group/')[-1]
                            resource_list.append(sg_id)
                        # Keep full ARN for other resources
                        else:
                            resource_list.append(arn)
            
            if resource_list:
                return ', '.join(resource_list)
        
        # Extract from request parameters if no resources in array
        if isinstance(request_params, dict):
            # EC2 instances
            if 'instancesSet' in request_params:
                instances = request_params['instancesSet'].get('items', [])
                if instances:
                    instance_ids = [i.get('instanceId', 'Unknown') for i in instances if isinstance(i, dict)]
                    if instance_ids:
                        return ', '.join(instance_ids)
            elif 'instanceId' in request_params:
                return request_params['instanceId']
            
            # S3 buckets
            elif 'bucketName' in request_params:
                return request_params['bucketName']
            
            # RDS databases
            elif 'dBInstanceIdentifier' in request_params:
                return request_params['dBInstanceIdentifier']
            elif 'dBClusterIdentifier' in request_params:
                return request_params['dBClusterIdentifier']
            
            # Lambda functions
            elif 'functionName' in request_params:
                return request_params['functionName']
            
            # EBS volumes
            elif 'volumeId' in request_params:
                return request_params['volumeId']
            
            # Security groups
            elif 'groupId' in request_params:
                return request_params['groupId']
            
            # IAM resources
            elif 'userName' in request_params:
                return f"IAMUser:{request_params['userName']}"
            elif 'roleName' in request_params:
                return f"IAMRole:{request_params['roleName']}"
            elif 'policyName' in request_params:
                return f"IAMPolicy:{request_params['policyName']}"
        
        # For Describe/List/Get operations, indicate it's a read operation
        if event_name.startswith(('Describe', 'List', 'Get')):
            service = event_source.split('.')[0].upper()
            return f"{service}:ReadOperation"
        
        # For Create/Delete/Update operations without specific resource
        if event_name.startswith(('Create', 'Delete', 'Update', 'Modify', 'Put')):
            service = event_source.split('.')[0].upper()
            return f"{service}:WriteOperation"
        
        # Default fallback
        return "UnknownResource"
    
    def format_event_for_promtail(self, event):
        """Format CloudTrail event for Promtail/Loki with enhanced tracking"""
        # Extract key information
        event_time = event.get('eventTime', '')
        event_name = event.get('eventName', 'Unknown')
        event_source = event.get('eventSource', 'Unknown')
        user_identity = event.get('userIdentity', {})
        
        # Extract user information with enhanced access key tracking
        user_type = user_identity.get('type', 'Unknown')
        principal_id = user_identity.get('principalId', 'Unknown')
        arn = user_identity.get('arn', 'Unknown')
        
        # Get enhanced access key identifier
        access_key_id = self.extract_access_key_identifier(user_identity)
        
        # Extract resource information with enhanced logic
        resource_names = self.extract_resource_names(event)
        
        # Request parameters
        request_params = event.get('requestParameters', {})
        
        # Response elements
        response_elements = event.get('responseElements', {})
        
        # Error information
        error_code = event.get('errorCode', '')
        error_message = event.get('errorMessage', '')
        
        # Source IP
        source_ip = event.get('sourceIPAddress', 'Unknown')
        
        # User agent
        user_agent = event.get('userAgent', 'Unknown')
        
        # AWS Region
        aws_region = event.get('awsRegion', 'Unknown')
        
        # Create structured log entry
        log_entry = {
            'timestamp': event_time,
            'event_name': event_name,
            'event_source': event_source,
            'user_type': user_type,
            'principal_id': principal_id,
            'arn': arn,
            'access_key_id': access_key_id,
            'source_ip': source_ip,
            'user_agent': user_agent,
            'aws_region': aws_region,
            'resources': resource_names,
            'error_code': error_code,
            'error_message': error_message,
            'request_parameters': json.dumps(request_params) if request_params else '',
            'response_elements': json.dumps(response_elements) if response_elements else '',
            'success': 'false' if error_code else 'true'
        }
        
        return log_entry
    
    def write_logs_for_promtail(self, events, source_file):
        """Write formatted logs to file for Promtail to pick up"""
        if not events:
            return
        
        # Create output file with timestamp
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
        output_file = self.output_dir / f"cloudtrail_{timestamp}.log"
        
        logger.info(f"Writing {len(events)} events to {output_file}")
        
        with open(output_file, 'w') as f:
            for event in events:
                formatted = self.format_event_for_promtail(event)
                # Write as JSON line
                f.write(json.dumps(formatted) + '\n')
        
        logger.info(f"Successfully wrote {len(events)} events")
    
    def cleanup_old_logs(self):
        """Clean up old processed log files"""
        retention_days = self.config.get('retention_days', 7)
        cutoff_time = datetime.utcnow() - timedelta(days=retention_days)
        
        deleted_count = 0
        for log_file in self.output_dir.glob('cloudtrail_*.log'):
            if datetime.fromtimestamp(log_file.stat().st_mtime) < cutoff_time:
                log_file.unlink()
                deleted_count += 1
        
        if deleted_count > 0:
            logger.info(f"Cleaned up {deleted_count} old log files")
    
    def process(self):
        """Main processing loop"""
        logger.info("Starting CloudTrail processing")
        
        # Load state
        state = self.load_state()
        
        # Get new log files
        new_files = self.list_new_logs(state)
        
        if not new_files:
            logger.info("No new files to process")
            return
        
        # Process each file
        total_events = 0
        for file_info in new_files:
            s3_key = file_info['key']
            
            # Download and parse
            events = self.download_and_parse_log(s3_key)
            
            if events:
                # Write formatted logs
                self.write_logs_for_promtail(events, s3_key)
                total_events += len(events)
            
            # Update state
            state['processed_files'].append(s3_key)
            state['last_processed_time'] = datetime.utcnow().isoformat()
            
            # Keep only last 1000 processed files in state
            if len(state['processed_files']) > 1000:
                state['processed_files'] = state['processed_files'][-1000:]
        
        # Save state
        self.save_state(state)
        
        logger.info(f"Processed {len(new_files)} files with {total_events} total events")
        
        # Cleanup old logs
        self.cleanup_old_logs()


def main():
    """Main entry point"""
    processor = CloudTrailProcessor()
    
    # Run once or in loop based on config
    run_mode = processor.config.get('run_mode', 'once')
    interval = processor.config.get('interval_seconds', 300)
    
    if run_mode == 'loop':
        logger.info(f"Running in loop mode with {interval}s interval")
        while True:
            try:
                processor.process()
            except Exception as e:
                logger.error(f"Error in processing loop: {e}", exc_info=True)
            
            time.sleep(interval)
    else:
        # Run once (for cron mode)
        processor.process()


if __name__ == '__main__':
    main()
