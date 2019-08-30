## AWS cost and usage reports

[![Build Status](https://travis-ci.com/telia-oss/terraform-aws-cost-and-usage-reports.svg?branch=master)](https://travis-ci.com/telia-oss/terraform-aws-cost-and-usage-reports)

AWS provides detailed cost and usage reports in csv format to the master account. This service takes these reports and converts them from csv to parquet (columnar storage format), sets up a AWS Glue Crawler and Database to allow quick searches through AWS Athena.

### Architecture
[AWS Cost and Usage Reports](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/billing-reports-costusage.html) creates reports periodically uploaded to an S3 bucket for the AWS Organizations master account. In our setup we don't do any actuall processing in the master account but instead forward all reports to a different bucket in another account. Reason for this is that we can fan out and send data to multiple buckets as well as moving the processing away from the master account limiting access. This part is optional and everything can be run in the master account.

The processing account has the following setup:

![Image](https://raw.githubusercontent.com/telia-oss/terraform-aws-cost-and-usage-reports/master/images/arch.svg?sanitize=true)

When AWS put a new file the cost and report bucket an event is created that triggered the manifest processor lambda function which processes the `Manifest.json` file. Since AWS does not overwrite existing reports when they are updated, the manifest contains a list of `ReportKeys` which are files that should be processed. It then cleans the destination bucket for the period specified in the manifest and then triggers a csv processor lambda function for each of these files.

The csv processor lambda function then reads the file it receives from the manifest processor and saves it partitioned by year and month to the output bucket.

Once all csv processor lambda functions have finished processing the manifest processor triggers the AWS Glue Crawler to crawl the bucket and update the database.

After this the database is available for query through Athena.

### Build lambda functions
```
> task build
# If you need to force a complete rebuild:
> task build --force
```
Note that building the csv-processor requires docker. This since the lambda need several thirdparty libraries and we need to build them in a lambda compatible environment.

### Deployment bucket
The lambda functions needs to be uploaded to an S3 bucket one they are build. If you already have a bucket you can use that (with versioning) or create one with terraform.
See [deploy-bucket example](https://github.com/telia-oss/terraform-aws-cost-and-usage-reports/tree/master/examples/deploy-bucket) for more info.

Since we run the processing in a different account then billing we create two buckets, one for each account.
If you want to run it in the billing account you can skip creating the billing-account bucket and uploading that lambda function.

### Upload lambda code
The functions can then be uploaded with the following command:
```
> BUCKET=my-lambda-deployment-bucket-in-billing-account task upload-lambda-billing-account 

> BUCKET=my-lambda-deployment-bucket-in-processing-account task upload-lambda-processing-account 
```

### Processing account
Setup the processing stack with the following terraform code:
```hcl
module "cost_and_usage_report" {
  source = "../../"

  report_bucket = "${data.aws_caller_identity.current.account_id}-reports-bucket"
  source_bucket = "${data.aws_caller_identity.current.account_id}-lambda-deploy-bucket"

  tags = {
    terraform   = "True"
    environment = "prod"
  }
}
```
Note that version 1.17.0 is needed for the AWS provider since we need the Glue Crawler resource.

### Billing account
The forwarding of reports from the billing account can be setup with the following terraform:
```hcl
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
```

### Setup the generation of the cost and usage report
Follow the Amazon guide for setting up the [AWS Cost and Usage report](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/billing-reports-gettingstarted-turnonreports.html). For time unit choose `Hourly`, include `Resource IDs` and choose the S3 bucket where the reports should be sent. Note that it can take up to 24 hours for the reports to appear.

### Athena example
Cost per product for all accounts in 05/2018
```
SELECT "product/productname" AS Product,
         SUM(CAST("lineitem/unblendedcost" AS DECIMAL(30,
        15))) AS Total
FROM "cost-and-usage-report"."parquet" 
WHERE year='2018'
        AND month='05'
GROUP BY  "product/productname"
ORDER BY  Total DESC;
```

Cost per usage type for a specific account in 05/2018
```
SELECT "lineitem/usagetype" AS UsageType,
         SUM(CAST("lineitem/unblendedcost" AS DECIMAL(30,
        15))) AS Total
FROM "cost-and-usage-report"."parquet" 
WHERE year='2018'
        AND month='05'
        AND "lineitem/usageaccountid"='my-account-id'
GROUP BY  "lineitem/usagetype"
ORDER BY  Total DESC;
```
