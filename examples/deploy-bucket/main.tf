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

resource "aws_s3_bucket" "lambda_deployment_bucket" {
  bucket = "${data.aws_caller_identity.current.account_id}-lambda-deploy-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}

output "lambda_deployment_bucket" {
  value = "${aws_s3_bucket.lambda_deployment_bucket.id}"
}
