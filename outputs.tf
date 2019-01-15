output "report_bucket_name" {
  description = "The name of the bucket the reports are delivered to."
  value       = "${aws_s3_bucket.cost_and_usage.id}"
}
