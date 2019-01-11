#!/bin/sh
export DIR="${PWD}"
cd built-source
export BUCKET=`cat deploy-bucket-terraform-out/terraform-out.json | jq -r '.lambda_deployment_bucket.value'`
make upload-lambda-billing-account
make upload-lambda-processing-account