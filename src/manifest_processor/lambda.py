# pylint: disable=import-error, too-many-locals, superfluous-parens
"""Lambda function for processing cost-and-usage manifest files."""
import json
import os
import re
from time import sleep

import boto3
from botocore.errorfactory import ClientError

CSV_PROCESSOR_LAMBDA = os.environ.get('CSV_PROCESSOR_LAMBDA')
GLUE_CRAWLER = os.environ.get('GLUE_CRAWLER')


def valid_manifest_key(key):
    """Validate manifest key to make sure only top level manifests are processed"""
    result = re.search(r'\d{8}-\d{8}\/((?:\w+-)+\w+)\.json$', key)
    if result:
        return True
    return False


def get_year_and_month(key):
    """Returns year and month from manifest key"""
    date = key.split('/')[-2]
    year = date[:4]
    month = date[4:6]
    return year, month


def clear_s3_path(bucket, prefix):
    """Clear existing files since we create new for each run"""
    s3_client = boto3.client('s3')
    print('Clearing s3://' + bucket + '/' + prefix)
    response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
    if 'Contents' in response:
        for obj in response['Contents']:
            s3_client.delete_object(Bucket=bucket, Key=obj['Key'])


def process_files(bucket, prefix, report_keys):
    """Loop through all files and trigger lambda functions for each"""
    target_keys = []
    lambda_client = boto3.client('lambda')
    for source_key in report_keys:
        print('Triggering lambda for s3://' + bucket + source_key)
        target_key = prefix + source_key.split('/')[-1].replace('csv.gz', 'snappy.parquet')
        payload = {
            'bucket': bucket,
            'source_key': source_key,
            'target_key': target_key
        }
        target_keys.append(target_key)
        lambda_client.invoke(
            FunctionName=CSV_PROCESSOR_LAMBDA,
            InvocationType='Event',
            Payload=json.dumps(payload)
        )
        print('Invokation sent for file s3://' + bucket + source_key)
    return target_keys


def lambda_handler(event, _):
    """Lambda entry point"""
    # Get bucket and key from event
    message = event['Records'][0]['Sns']['Message']
    parsed_message = json.loads(message)
    bucket = parsed_message['Records'][0]['s3']['bucket']['name']
    key = parsed_message['Records'][0]['s3']['object']['key']

    # Make sure we are only processing to level manifests
    if not valid_manifest_key(key):
        print('Skippning since its not the root manifest file s3://' + bucket + '/' + key)
        return True

    print('Processing manifest s3://' + bucket + '/' + key)

    # Load manifest file
    s3_client = boto3.client('s3')
    manifest_file = s3_client.get_object(Bucket=bucket, Key=key)
    manifest = json.loads(manifest_file['Body'].read())

    # Get year and month from manifest key to partition on
    year, month = get_year_and_month(key)
    prefix = 'parquet/' + 'year=' + year + '/month=' + month + '/'

    # Clean output path
    clear_s3_path(bucket, prefix)

    # Process report files from the manifest
    report_keys = manifest['reportKeys']
    processed_files = process_files(bucket, prefix, report_keys)

    # Validate that files are there
    for key in processed_files:
        found = False
        while(not found):
            try:
                s3_client.head_object(Bucket=bucket, Key=key)
            except ClientError:
                print('Waiting for: "' + key + '" to exist')
                sleep(10)
            else:
                print('Found: "' + key + '"')
                found = True

    print('All files ok')

    print('Triggering Glue crawler')

    glue_client = boto3.client('glue')
    glue_client.start_crawler(
        Name=GLUE_CRAWLER
    )

    print('Done processing')

    return True
