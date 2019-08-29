variable "name_prefix" {
  type    = string
  default = "cost-and-usage-basic-example"
}

variable "lambda_artifacts" {
  type    = list(string)
  default = ["bucket_forwarder.zip", "csv_processor.zip", "manifest_processor.zip"]
}

variable "region" {
  type    = string
  default = "eu-west-1"
}
