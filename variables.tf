variable "name_prefix" {
  description = "Prefix used for resource names."
  type        = string
  default     = "cost-and-usage-report"
}

variable "report_bucket" {
  description = "Bucket name where reports will be saved."
  type        = string
}

variable "source_bucket" {
  description = "Bucket where lambda funtions are uploaded."
  type        = string
}

variable "source_path" {
  description = "Bucket path where lambda functions are uploaded."
  type        = string
  default     = "lambda"
}

variable "billing_account_id" {
  description = "AWS account id for the account that will forward the reports, defaults to the Magic AWS account number that uploads the billing reports from Amazon."
  type        = string
  default     = "386209384616"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

