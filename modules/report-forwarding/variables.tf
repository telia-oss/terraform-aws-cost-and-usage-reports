variable "prefix" {
  description = "Prefix used for resource names."
  type        = string
  default     = "cost-and-usage-report"
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

variable "report_bucket" {
  description = "Bucket name where reports will be saved."
  type        = string
}

variable "aws_billing_account_id" {
  description = "Magic AWS account number that uploads the billing reports."
  type        = string
  default     = "386209384616"
}

variable "destination_buckets" {
  description = "A list of buckets upload reports to."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

