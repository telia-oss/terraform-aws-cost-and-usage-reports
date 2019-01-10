terraform {
  required_version = "0.11.11"

  backend "s3" {
    key            = "terraform-modules/development/terraform-aws-cost-and-usage-reports/report-forwarding.tfstate"
    bucket         = "<test-account-id>-terraform-state"
    dynamodb_table = "<test-account-id>-terraform-state"
    acl            = "bucket-owner-full-control"
    encrypt        = "true"
    kms_key_id     = "<kms-key-id>"
    region         = "eu-west-1"
  }
}

provider "aws" {
  version             = "1.52.0"
  region              = "eu-west-1"
  allowed_account_ids = ["<test-account-id>"]
}

locals {
  name_prefix = "test-forwarding-cost-and-usage"
}

resource "aws_s3_bucket" "lambda_deployment_bucket" {
  bucket = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-lambda-deploy-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}

resource "aws_s3_bucket" "first-cost-and-usage-reports-bucket" {
  bucket = "test-report-forwarding-owrughe-bucket-1"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}

resource "aws_s3_bucket" "second-cost-and-usage-reports-bucket" {
  bucket = "test-report-forwarding-owrughe-bucket-2"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}

data "aws_caller_identity" "current" {}

module "cost_and_usage_report" {
  source = "../../modules/report-forwarding"

  report_bucket = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-reports-bucket"
  source_bucket = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-lambda-deploy-bucket"

  destination_buckets = [
    "test-report-forwarding-owrughe-bucket-1",
    "test-report-forwarding-owrughe-bucket-2",
  ]

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}

output "report_bucket_name" {
  value = "${module.cost_and_usage_report.report_bucket_name}"
}
