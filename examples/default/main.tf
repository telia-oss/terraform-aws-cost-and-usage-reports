terraform {
  required_version = "0.11.11"

  backend "s3" {
    key            = "terraform-modules/development/terraform-aws-cost-and-usage-reports/default.tfstate"
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

module "cost_and_usage_report" {
  source = "../../"

  report_bucket = "${data.aws_caller_identity.current.account_id}-reports-bucket"
  source_bucket = "${data.aws_caller_identity.current.account_id}-lambda-deploy-bucket"

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}

output "report_bucket_name" {
  value = "${module.cost_and_usage_report.report_bucket_name}"
}
