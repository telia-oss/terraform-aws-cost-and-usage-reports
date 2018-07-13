provider "aws" {
  region  = "eu-west-1"
  version = "1.27.0"
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
