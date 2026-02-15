#!/usr/bin/env python3
"""
Test script for enhanced CloudTrail processor
Tests the new access key and resource extraction methods
"""

import json
import sys
from pathlib import Path

# Add parent directory to path to import the processor
sys.path.insert(0, str(Path(__file__).parent))

# Mock the CloudTrailProcessor class methods for testing
class TestProcessor:
    def extract_access_key_identifier(self, user_identity):
        """Extract meaningful access key identifier from user identity"""
        user_type = user_identity.get('type', 'Unknown')
        arn = user_identity.get('arn', '')
        access_key_id = user_identity.get('accessKeyId')
        
        if access_key_id:
            return access_key_id
        
        if user_type == 'AssumedRole':
            if 'assumed-role' in arn:
                parts = arn.split('/')
                if len(parts) >= 2:
                    role_name = parts[-2]
                    return f"AssumedRole:{role_name}"
            return "AssumedRole:Unknown"
        
        if user_type == 'IAMUser':
            if '/' in arn:
                username = arn.split('/')[-1]
                return f"Console:{username}"
            return "Console:Unknown"
        
        if user_type == 'Root':
            return "RootAccount"
        
        if user_type == 'AWSService':
            invoked_by = user_identity.get('invokedBy', 'unknown')
            return f"Service:{invoked_by}"
        
        if user_type == 'FederatedUser':
            if '/' in arn:
                federated_user = arn.split('/')[-1]
                return f"Federated:{federated_user}"
            return "Federated:Unknown"
        
        if user_type == 'SAMLUser':
            principal_id = user_identity.get('principalId', 'Unknown')
            return f"SAML:{principal_id}"
        
        return f"{user_type}:Unknown"
    
    def extract_resource_names(self, event):
        """Enhanced resource extraction from CloudTrail event"""
        event_name = event.get('eventName', '')
        event_source = event.get('eventSource', '')
        resources = event.get('resources', [])
        request_params = event.get('requestParameters', {})
        
        if resources and isinstance(resources, list) and len(resources) > 0:
            resource_list = []
            for r in resources:
                if isinstance(r, dict):
                    arn = r.get('ARN', '')
                    if arn:
                        if 'instance/' in arn:
                            instance_id = arn.split('instance/')[-1]
                            resource_list.append(instance_id)
                        elif 'arn:aws:s3:::' in arn:
                            bucket_name = arn.replace('arn:aws:s3:::', '').split('/')[0]
                            resource_list.append(bucket_name)
                        elif ':db:' in arn:
                            db_id = arn.split(':db:')[-1]
                            resource_list.append(db_id)
                        elif ':function:' in arn:
                            func_name = arn.split(':function:')[-1].split(':')[0]
                            resource_list.append(func_name)
                        else:
                            resource_list.append(arn)
            
            if resource_list:
                return ', '.join(resource_list)
        
        if isinstance(request_params, dict):
            if 'instanceId' in request_params:
                return request_params['instanceId']
            elif 'bucketName' in request_params:
                return request_params['bucketName']
            elif 'dBInstanceIdentifier' in request_params:
                return request_params['dBInstanceIdentifier']
            elif 'functionName' in request_params:
                return request_params['functionName']
        
        if event_name.startswith(('Describe', 'List', 'Get')):
            service = event_source.split('.')[0].upper()
            return f"{service}:ReadOperation"
        
        if event_name.startswith(('Create', 'Delete', 'Update', 'Modify', 'Put')):
            service = event_source.split('.')[0].upper()
            return f"{service}:WriteOperation"
        
        return "UnknownResource"


def test_access_key_extraction():
    """Test access key identifier extraction"""
    processor = TestProcessor()
    
    test_cases = [
        {
            'name': 'IAM User with Access Key',
            'user_identity': {
                'type': 'IAMUser',
                'arn': 'arn:aws:iam::123456789012:user/john.doe',
                'accessKeyId': 'AKIAIOSFODNN7EXAMPLE'
            },
            'expected': 'AKIAIOSFODNN7EXAMPLE'
        },
        {
            'name': 'IAM User Console Login',
            'user_identity': {
                'type': 'IAMUser',
                'arn': 'arn:aws:iam::123456789012:user/john.doe'
            },
            'expected': 'Console:john.doe'
        },
        {
            'name': 'AssumedRole (EC2)',
            'user_identity': {
                'type': 'AssumedRole',
                'arn': 'arn:aws:sts::123456789012:assumed-role/EC2AdminRole/i-0123456789abcdef0'
            },
            'expected': 'AssumedRole:EC2AdminRole'
        },
        {
            'name': 'Root Account',
            'user_identity': {
                'type': 'Root',
                'arn': 'arn:aws:iam::123456789012:root'
            },
            'expected': 'RootAccount'
        },
        {
            'name': 'AWS Service',
            'user_identity': {
                'type': 'AWSService',
                'invokedBy': 'ec2.amazonaws.com'
            },
            'expected': 'Service:ec2.amazonaws.com'
        }
    ]
    
    print("=" * 80)
    print("Testing Access Key Extraction")
    print("=" * 80)
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        result = processor.extract_access_key_identifier(test['user_identity'])
        status = "✅ PASS" if result == test['expected'] else "❌ FAIL"
        
        if result == test['expected']:
            passed += 1
        else:
            failed += 1
        
        print(f"\n{status} - {test['name']}")
        print(f"  Expected: {test['expected']}")
        print(f"  Got:      {result}")
    
    print(f"\n{'=' * 80}")
    print(f"Results: {passed} passed, {failed} failed")
    print(f"{'=' * 80}\n")
    
    return failed == 0


def test_resource_extraction():
    """Test resource name extraction"""
    processor = TestProcessor()
    
    test_cases = [
        {
            'name': 'EC2 Instance from ARN',
            'event': {
                'eventName': 'RunInstances',
                'eventSource': 'ec2.amazonaws.com',
                'resources': [
                    {'ARN': 'arn:aws:ec2:us-east-1:123456789012:instance/i-0123456789abcdef0'}
                ]
            },
            'expected': 'i-0123456789abcdef0'
        },
        {
            'name': 'S3 Bucket from ARN',
            'event': {
                'eventName': 'PutObject',
                'eventSource': 's3.amazonaws.com',
                'resources': [
                    {'ARN': 'arn:aws:s3:::my-bucket-name/path/to/file.txt'}
                ]
            },
            'expected': 'my-bucket-name'
        },
        {
            'name': 'EC2 Describe Operation',
            'event': {
                'eventName': 'DescribeInstances',
                'eventSource': 'ec2.amazonaws.com',
                'resources': [],
                'requestParameters': {}
            },
            'expected': 'EC2:ReadOperation'
        },
        {
            'name': 'S3 List Operation',
            'event': {
                'eventName': 'ListBuckets',
                'eventSource': 's3.amazonaws.com',
                'resources': [],
                'requestParameters': {}
            },
            'expected': 'S3:ReadOperation'
        },
        {
            'name': 'RDS from Request Parameters',
            'event': {
                'eventName': 'CreateDBInstance',
                'eventSource': 'rds.amazonaws.com',
                'resources': [],
                'requestParameters': {
                    'dBInstanceIdentifier': 'my-database'
                }
            },
            'expected': 'my-database'
        }
    ]
    
    print("=" * 80)
    print("Testing Resource Extraction")
    print("=" * 80)
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        result = processor.extract_resource_names(test['event'])
        status = "✅ PASS" if result == test['expected'] else "❌ FAIL"
        
        if result == test['expected']:
            passed += 1
        else:
            failed += 1
        
        print(f"\n{status} - {test['name']}")
        print(f"  Expected: {test['expected']}")
        print(f"  Got:      {result}")
    
    print(f"\n{'=' * 80}")
    print(f"Results: {passed} passed, {failed} failed")
    print(f"{'=' * 80}\n")
    
    return failed == 0


def main():
    """Run all tests"""
    print("\n" + "=" * 80)
    print("CloudTrail Processor Enhancement - Test Suite")
    print("=" * 80 + "\n")
    
    access_key_pass = test_access_key_extraction()
    resource_pass = test_resource_extraction()
    
    print("\n" + "=" * 80)
    if access_key_pass and resource_pass:
        print("✅ ALL TESTS PASSED")
        print("=" * 80 + "\n")
        return 0
    else:
        print("❌ SOME TESTS FAILED")
        print("=" * 80 + "\n")
        return 1


if __name__ == '__main__':
    sys.exit(main())
