#!/bin/sh
export DIR="${PWD}"
export BUCKET=`cat deploy-bucket-terraform-out/terraform-out.json | jq -r '.lambda_deployment_bucket.value'`
cd built-source
make upload-lambda-billing-account
make upload-lambda-processing-account