provider "aws" {
  region  = "eu-west-1"
  version = "1.27.0"
}

data "aws_caller_identity" "current" {}

module "cost_and_usage_report" {
  source = "../../modules/report-forwarding"

  report_bucket = "${data.aws_caller_identity.current.account_id}-reports-bucket"
  source_bucket = "${data.aws_caller_identity.current.account_id}-lambda-deploy-bucket"

  destination_buckets = [
    "first-cost-and-usage-reports-bucket",
    "second-cost-and-usage-reports-bucket",
  ]

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}

output "report_bucket_name" {
  value = "${module.cost_and_usage_report.report_bucket_name}"
}
