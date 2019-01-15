variable "name_prefix" {
  description = "Prefix used for resource names."
  default     = "cost-and-usage-report"
}

variable "report_bucket" {
  description = "Bucket name where reports will be saved."
}

variable "source_bucket" {
  description = "Bucket where lambda funtions are uploaded."
}

variable "source_path" {
  description = "Bucket path where lambda functions are uploaded."
  default     = "lambda"
}

variable "billing_account_id" {
  description = "AWS account id for the account that will forward the reports, defaults to the Magic AWS account number that uploads the billing reports from Amazon."
  default     = "386209384616"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}
