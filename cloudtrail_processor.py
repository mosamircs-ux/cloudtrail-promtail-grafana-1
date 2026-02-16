#!/usr/bin/env python3
"""
CloudTrail S3 Log Processor
Downloads CloudTrail logs from S3, parses them, and writes formatted logs for Promtail
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
            start_time = datetime.fromisoformat(state['last_processed_time']).replace(tzinfo=None)
        else:
            # First run - get logs from configurable lookback (default 7 days for full account history)
            lookback_days = self.config.get('initial_lookback_days', 7)
            start_time = datetime.utcnow() - timedelta(days=lookback_days)
            logger.info(f"First run: processing logs from last {lookback_days} days to capture ALL users/keys/resources")
        
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
    
    def _extract_iam_username(self, user_identity):
        """
        Extract IAM username from user identity for display purposes.
        Returns human-readable username (e.g. 'john.doe') instead of principal ID (e.g. 'AIDAR2CXKSGHHQEKL6O4C').
        """
        # CloudTrail provides userName for IAM users
        user_name = user_identity.get('userName', '')
        if user_name:
            return user_name

        user_type = user_identity.get('type', 'Unknown')
        arn = user_identity.get('arn', '')

        # IAM User: extract from ARN (arn:aws:iam::123456789012:user/john.doe)
        if user_type == 'IAMUser' and '/' in arn:
            return arn.split('/')[-1]

        # AssumedRole: extract role name (arn:aws:sts::...:assumed-role/RoleName/session-name)
        if user_type == 'AssumedRole' and 'assumed-role/' in arn:
            parts = arn.split('assumed-role/')[-1].split('/')
            if len(parts) >= 2:
                return f"{parts[0]}/{parts[1]}"  # role/session
            return parts[0] if parts else 'Unknown'

        # FederatedUser: extract from ARN
        if user_type == 'FederatedUser' and '/' in arn:
            return arn.split('/')[-1]

        # Root
        if user_type == 'Root':
            return 'root'

        # AWSService: extract service name
        if user_type == 'AWSService':
            invoked_by = user_identity.get('invokedBy', 'unknown')
            return invoked_by.split('.')[0] if '.' in invoked_by else invoked_by

        # principalId format "AIDAXXX:username" - username after colon (when present)
        principal_id = user_identity.get('principalId', '')
        if principal_id and ':' in principal_id:
            return principal_id.split(':', 1)[-1]

        return principal_id if principal_id else 'Unknown'

    def extract_access_key_identifier(self, user_identity):
        """
        Extract meaningful access key identifier from user identity
        Returns actual access key or descriptive identifier
        """
        user_type = user_identity.get('type', 'Unknown')
        arn = user_identity.get('arn', '')
        access_key_id = user_identity.get('accessKeyId')
        
        # If access key exists at top level, use it
        if access_key_id:
            return access_key_id
        
        # Check session context for access key (common in AssumedRole and AWS Service events)
        session_context = user_identity.get('sessionContext', {})
        if isinstance(session_context, dict):
            # Check session issuer for access key
            session_issuer = session_context.get('sessionIssuer', {})
            if isinstance(session_issuer, dict):
                # Some services store the access key in sessionIssuer
                issuer_access_key = session_issuer.get('accessKeyId')
                if issuer_access_key:
                    return issuer_access_key
            
            # Check attributes for access key
            attributes = session_context.get('attributes', {})
            if isinstance(attributes, dict):
                # MFA device or creation date might indicate the source
                mfa_authenticated = attributes.get('mfaAuthenticated', 'false')
                creation_date = attributes.get('creationDate', '')
        
        # AssumedRole - try to extract access key from session context first
        if user_type == 'AssumedRole':
            # Check if there's a source identity (the original caller)
            source_identity = user_identity.get('sourceIdentity')
            if source_identity:
                return f"AssumedBy:{source_identity}"
            
            # Try to get principal ID which might contain the access key
            principal_id = user_identity.get('principalId', '')
            if principal_id and ':' in principal_id:
                # Format is usually "uniqueID:sessionName"
                # The session name might give us info about who assumed the role
                parts = principal_id.split(':')
                if len(parts) >= 2:
                    session_name = parts[-1]
                    # If it looks like an access key (starts with AKIA), use it
                    if session_name.startswith('AKIA') or session_name.startswith('ASIA'):
                        return session_name
                    # Otherwise return a descriptive name
                    return f"AssumedRole:{session_name}"
            
            # Fall back to extracting role name from ARN
            if 'assumed-role' in arn:
                parts = arn.split('/')
                if len(parts) >= 2:
                    role_name = parts[-2]
                    session_name = parts[-1] if len(parts) >= 3 else 'unknown'
                    return f"AssumedRole:{role_name}/{session_name}"
            return "AssumedRole:Unknown"
        
        # IAM User - likely console login or access key
        if user_type == 'IAMUser':
            if '/' in arn:
                username = arn.split('/')[-1]
                return username  # Just return username, cleaner
            return "IAMUser:Unknown"
        
        # Root Account
        if user_type == 'Root':
            # Check if there's an access key in session context for root
            account_id = user_identity.get('accountId', 'Unknown')
            return f"RootAccount:{account_id}"
        
        # AWS Service - extract clean service name
        if user_type == 'AWSService':
            invoked_by = user_identity.get('invokedBy', 'unknown.amazonaws.com')
            
            # Extract clean service name from invokedBy
            # e.g., "cloudfront.amazonaws.com" -> "CloudFront"
            if '.' in invoked_by:
                service_name = invoked_by.split('.')[0]
                
                # Special cases for better naming
                service_map = {
                    'cloudfront': 'CloudFront',
                    'elasticloadbalancing': 'ELB',
                    'lambda': 'Lambda',
                    's3': 'S3',
                    'ec2': 'EC2',
                    'rds': 'RDS',
                    'dynamodb': 'DynamoDB',
                    'sns': 'SNS',
                    'sqs': 'SQS',
                    'ecs': 'ECS',
                    'eks': 'EKS',
                    'cloudwatch': 'CloudWatch',
                    'backup': 'AWS Backup',
                    'config': 'AWS Config',
                    'trustedadvisor': 'Trusted Advisor'
                }
                
                service_name_lower = service_name.lower()
                if service_name_lower in service_map:
                    return service_map[service_name_lower]
                
                # Capitalize first letter for unknown services
                return service_name.capitalize()
            
            # If no dot in invokedBy, return as-is
            return invoked_by
        
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
        
        # Web Identity User
        if user_type == 'WebIdentityUser':
            principal_id = user_identity.get('principalId', 'Unknown')
            return f"WebIdentity:{principal_id}"
        
        # Unknown type - return N/A instead of confusing identifier
        return "N/A"
    
    def extract_resource_names(self, event):
        """
        Enhanced resource extraction from CloudTrail event
        Returns meaningful resource identifiers or operation type
        """
        event_name = event.get('eventName', '')
        event_source = event.get('eventSource', '')
        resources = event.get('resources', [])
        request_params = event.get('requestParameters', {})
        response_elements = event.get('responseElements', {})
        
        # Try to extract from resources array first
        if resources and isinstance(resources, list) and len(resources) > 0:
            resource_list = []
            for r in resources:
                if isinstance(r, dict):
                    arn = r.get('ARN', '')
                    if arn:
                        # Skip CloudTrail bucket ARNs (these are just metadata)
                        if 'cloudtrail-logs' in arn.lower():
                            continue
                            
                        # Extract instance ID from EC2 ARN
                        if 'instance/' in arn:
                            instance_id = arn.split('instance/')[-1]
                            resource_list.append(instance_id)
                        # Extract bucket name from S3 ARN
                        elif 'arn:aws:s3:::' in arn:
                            bucket_name = arn.replace('arn:aws:s3:::', '').split('/')[0]
                            # Skip CloudTrail buckets
                            if 'cloudtrail-logs' not in bucket_name.lower():
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
            # EC2 instances - various formats
            if 'instancesSet' in request_params:
                instances = request_params['instancesSet'].get('items', [])
                if instances:
                    instance_ids = [i.get('instanceId', 'Unknown') for i in instances if isinstance(i, dict)]
                    if instance_ids:
                        return ', '.join(instance_ids)
            elif 'instanceId' in request_params:
                return request_params['instanceId']
            
            # DescribeInstances - extract from filters
            elif event_name == 'DescribeInstances' and 'filterSet' in request_params:
                filters = request_params.get('filterSet', {}).get('items', [])
                instance_ids = []
                for f in filters:
                    if isinstance(f, dict) and f.get('name') == 'instance-id':
                        values = f.get('valueSet', {}).get('items', [])
                        for v in values:
                            if isinstance(v, dict) and 'value' in v:
                                instance_ids.append(v['value'])
                if instance_ids:
                    return ', '.join(instance_ids)
                else:
                    # If no instance filter, get from response
                    return self._extract_from_describe_instances_response(response_elements)
            
            # S3 operations - handle both bucket and object operations
            if 'bucketName' in request_params:
                bucket = request_params['bucketName']
                # Skip CloudTrail buckets
                if 'cloudtrail-logs' not in bucket.lower():
                    # If there's also a key, show bucket/key
                    if 'key' in request_params:
                        key = request_params['key']
                        # Truncate long keys
                        if len(key) > 50:
                            key = key[:47] + '...'
                        return f"{bucket}/{key}"
                    else:
                        # Just bucket operation
                        return bucket
            
            # S3 object operations without bucketName in request (rare)
            elif 'key' in request_params:
                # Try to find bucket in response
                if isinstance(response_elements, dict) and 'bucketName' in response_elements:
                    bucket = response_elements['bucketName']
                    if 'cloudtrail-logs' not in bucket.lower():
                        key = request_params['key']
                        if len(key) > 50:
                            key = key[:47] + '...'
                        return f"{bucket}/{key}"
                # Try to extract from event source
                elif event_source == 's3.amazonaws.com':
                    key = request_params['key']
                    if len(key) > 50:
                        key = key[:47] + '...'
                    return f"S3Object:{key}"
            
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
        
        # Extract from response elements for Create operations
        if isinstance(response_elements, dict) and event_name.startswith('Create'):
            # EC2 instances
            if 'instancesSet' in response_elements:
                instances = response_elements['instancesSet'].get('items', [])
                if instances:
                    instance_ids = [i.get('instanceId', 'Unknown') for i in instances if isinstance(i, dict)]
                    if instance_ids:
                        return ', '.join(instance_ids)
            
            # S3 buckets
            elif 'bucketName' in response_elements:
                bucket = response_elements['bucketName']
                if 'cloudtrail-logs' not in bucket.lower():
                    return bucket
            
            # Lambda functions
            elif 'functionName' in response_elements:
                return response_elements['functionName']
            
            # RDS instances
            elif 'dBInstanceIdentifier' in response_elements:
                return response_elements['dBInstanceIdentifier']
        
        # For Describe/List/Get operations, try to extract from response
        if event_name.startswith(('Describe', 'List', 'Get')):
            # DescribeInstances - extract all instance IDs from response
            if event_name == 'DescribeInstances':
                instances = self._extract_from_describe_instances_response(response_elements)
                if instances:
                    return instances
            
            # ListBuckets - this is account-level, so keep it generic
            # but other List operations might have specific resources
            
            service = event_source.split('.')[0].upper()
            return f"{service}:ReadOperation"
        
        # For Create/Delete/Update operations without specific resource
        if event_name.startswith(('Create', 'Delete', 'Update', 'Modify', 'Put')):
            service = event_source.split('.')[0].upper()
            return f"{service}:WriteOperation"
        
        # Default fallback
        return "UnknownResource"
    
    def _extract_from_describe_instances_response(self, response_elements):
        """Extract instance IDs from DescribeInstances response"""
        if not isinstance(response_elements, dict):
            return None
        
        reservation_set = response_elements.get('reservationSet', {})
        if not isinstance(reservation_set, dict):
            return None
        
        items = reservation_set.get('items', [])
        if not items:
            return None
        
        instance_ids = []
        for reservation in items:
            if isinstance(reservation, dict):
                instances_set = reservation.get('instancesSet', {})
                if isinstance(instances_set, dict):
                    instances = instances_set.get('items', [])
                    for instance in instances:
                        if isinstance(instance, dict) and 'instanceId' in instance:
                            instance_ids.append(instance['instanceId'])
        
        if instance_ids:
            # Limit to first 5 instances to avoid too long strings
            if len(instance_ids) > 5:
                return ', '.join(instance_ids[:5]) + f' (+{len(instance_ids)-5} more)'
            return ', '.join(instance_ids)
        
        return None

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
        iam_username = self._extract_iam_username(user_identity)
        
        # Get enhanced access key identifier
        access_key_id = self.extract_access_key_identifier(user_identity)
        
        # If we got a generic service identifier, try to find the actual access key
        # by searching deeper in the event structure
        if access_key_id.startswith('Service:') or access_key_id.startswith('AssumedRole:'):
            # Search in resources array for access key info
            resources = event.get('resources', [])
            for resource in resources:
                if isinstance(resource, dict):
                    account_id = resource.get('accountId', '')
                    # Check if ARN contains access key info
                    res_arn = resource.get('ARN', '')
                    if 'AKIA' in res_arn or 'ASIA' in res_arn:
                        # Extract the access key from the ARN
                        for part in res_arn.split('/'):
                            if part.startswith('AKIA') or part.startswith('ASIA'):
                                access_key_id = part
                                break
            
            # Search in request parameters for access key
            request_params = event.get('requestParameters', {})
            if isinstance(request_params, dict):
                # Check for accessKeyId field
                if 'accessKeyId' in request_params:
                    access_key_id = request_params['accessKeyId']
                # Check for credentials field
                elif 'credentials' in request_params:
                    creds = request_params['credentials']
                    if isinstance(creds, dict) and 'accessKeyId' in creds:
                        access_key_id = creds['accessKeyId']
        
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
            'iam_username': iam_username,
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
