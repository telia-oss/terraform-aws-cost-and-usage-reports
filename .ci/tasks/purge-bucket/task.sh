#!/bin/sh
set -euo pipefail

export AWS_DEFAULT_REGION=eu-west-1
BUCKET_NAME=`cat terraform-out/terraform-out.json | jq -r '.lambda_deployment_bucket.value'`

aws s3 rm s3://$BUCKET_NAME --recursive