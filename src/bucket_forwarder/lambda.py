"""Lambda function for forward content of one bucket to multiple other buckets"""
import ast
import os
import urllib
import boto3

FORWARD_BUCKETS = os.environ.get('FORWARD_BUCKETS')

def lambda_handler(event, _):
    """Lambda entry point"""
    s3_client = boto3.client('s3')
    sns_message = ast.literal_eval(event['Records'][0]['Sns']['Message'])
    source_bucket = str(sns_message['Records'][0]['s3']['bucket']['name'])
    key = str(urllib.unquote_plus(sns_message['Records'][0]['s3']['object']['key']).decode('utf8'))
    copy_source = {'Bucket':source_bucket, 'Key':key}

    for target_bucket in FORWARD_BUCKETS.split(","):
        print "Copying %s from bucket %s to bucket %s ..." % (key, source_bucket, target_bucket)
        s3_client.copy_object(
            Bucket=target_bucket,
            Key=key,
            CopySource=copy_source,
            ACL="bucket-owner-full-control"
        )

    return True
