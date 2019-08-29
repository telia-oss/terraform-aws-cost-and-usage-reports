terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = ">= 2.17"
  region  = var.region
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.name_prefix}-lambda-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    environment = "dev"
    terraform   = "True"
  }
}

resource "aws_s3_bucket_object" "artifact" {
  count  = length(var.lambda_artifacts)
  bucket = aws_s3_bucket.artifacts.id
  key    = "lambda/${var.lambda_artifacts[count.index]}"
  source = "${path.module}/../../dist/${var.lambda_artifacts[count.index]}"
  etag   = filemd5("${path.module}/../../dist/${var.lambda_artifacts[count.index]}")
}

module "report_processing" {
  source = "../../"

  name_prefix        = var.name_prefix
  report_bucket      = "${data.aws_caller_identity.current.account_id}-${var.name_prefix}-processing-bucket"
  source_bucket      = aws_s3_bucket_object.artifact[0].bucket
  billing_account_id = data.aws_caller_identity.current.account_id

  tags = {
    environment = "dev"
    terraform   = "True"
  }
}

module "report_forwarding" {
  source = "../../modules/report-forwarding"

  report_bucket       = "${data.aws_caller_identity.current.account_id}-${var.name_prefix}-forwarding-bucket"
  source_bucket       = aws_s3_bucket_object.artifact[0].bucket
  destination_buckets = [module.report_processing.report_bucket_name]

  tags = {
    environment = "dev"
    terraform   = "True"
  }
}
