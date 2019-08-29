
output "report_bucket_name" {
  value = module.report_forwarding.report_bucket_name
}

output "destination_bucket_name" {
  value = module.report_processing.report_bucket_name
}
