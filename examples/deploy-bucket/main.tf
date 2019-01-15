terraform {
  required_version = "0.11.11"

  backend "s3" {
    key            = "terraform-modules/development/terraform-aws-cost-and-usage-reports/deploy-bucket.tfstate"
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

data "aws_caller_identity" "current" {}

# versioning set to false so that bucket can be created and deleted by testing pipeline - recommend setting to true for prod use!
resource "aws_s3_bucket" "lambda_deployment_bucket" {
  bucket = "test-<test-account-id>-lambda-deploy-bucket"
  acl    = "private"

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}

output "lambda_deployment_bucket" {
  value = "${aws_s3_bucket.lambda_deployment_bucket.bucket}"
}
