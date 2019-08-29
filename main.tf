# ------------------------------------------------------------------------------
# S3 bucket
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "cost_and_usage" {
  bucket = var.report_bucket
  acl    = "private"

  tags = var.tags
}

resource "aws_s3_bucket_policy" "cost_and_usage" {
  bucket = aws_s3_bucket.cost_and_usage.id

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Id": "MASTERACCOUNTACCESSPOLICY",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.billing_account_id}:root"
      },
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "${aws_s3_bucket.cost_and_usage.arn}/*"
    }
  ]
}
POLICY

}

resource "aws_s3_bucket_notification" "cost_and_usage_notification" {
  bucket = aws_s3_bucket.cost_and_usage.id

  topic {
    topic_arn = aws_sns_topic.cost_and_usage.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_s3_bucket.cost_and_usage]
}

# ------------------------------------------------------------------------------
# SNS
# ------------------------------------------------------------------------------

resource "aws_sns_topic" "cost_and_usage" {
  name = "${var.name_prefix}-topic"
}

resource "aws_sns_topic_policy" "cost_and_usage" {
  arn    = aws_sns_topic.cost_and_usage.arn
  policy = data.aws_iam_policy_document.cost_and_usage_topic_policy.json
}

data "aws_iam_policy_document" "cost_and_usage_topic_policy" {
  statement {
    actions = [
      "SNS:Publish",
    ]

    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"

      values = [
        aws_s3_bucket.cost_and_usage.arn,
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.cost_and_usage.arn,
    ]
  }
}

# ------------------------------------------------------------------------------
# AWS glue
# ------------------------------------------------------------------------------

resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  name = var.name_prefix
}

// TODO: RENAME
resource "aws_iam_role" "glue" {
  name = "${var.name_prefix}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

// TODO: RENAME
resource "aws_iam_role_policy" "bucket_access" {
  name = "bucket-access"
  role = aws_iam_role.glue.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.cost_and_usage.arn}",
        "${aws_s3_bucket.cost_and_usage.arn}/*"
      ]
    }
  ]
}
EOF

}

resource "aws_glue_crawler" "glue_crawler" {
  database_name = aws_glue_catalog_database.aws_glue_catalog_database.name
  name          = "${var.name_prefix}-crawler"
  role          = aws_iam_role.glue.id

  s3_target {
    path = "s3://${aws_s3_bucket.cost_and_usage.id}/parquet/"
  }
}

# ------------------------------------------------------------------------------
# manifest processor lambda
# ------------------------------------------------------------------------------

data "aws_s3_bucket_object" "manifest_processor" {
  bucket = var.source_bucket
  key    = "${var.source_path}/manifest_processor.zip"
}

resource "aws_lambda_function" "manifest_processor" {
  function_name     = "${var.name_prefix}-manifest-processor-function"
  description       = "Lambda function."
  handler           = "lambda.lambda_handler"
  runtime           = "python2.7"
  memory_size       = "3008"
  timeout           = "300"
  s3_bucket         = data.aws_s3_bucket_object.manifest_processor.bucket
  s3_key            = data.aws_s3_bucket_object.manifest_processor.key
  s3_object_version = data.aws_s3_bucket_object.manifest_processor.version_id
  role              = aws_iam_role.manifest_processor.arn

  environment {
    variables = {
      CSV_PROCESSOR_LAMBDA = aws_lambda_function.csv_processor.function_name
      GLUE_CRAWLER         = "${var.name_prefix}-crawler"
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "manifest_processor" {
  name               = "${var.name_prefix}-manifest-processor-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.manifest_processor_assume.json
}

data "aws_iam_policy_document" "manifest_processor_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "manifest_processor" {
  name   = "${var.name_prefix}-manifest-processor-lambda-privileges"
  role   = aws_iam_role.manifest_processor.name
  policy = data.aws_iam_policy_document.manifest_processor.json
}

data "aws_iam_policy_document" "manifest_processor" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ListAllMyBuckets",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    effect = "Allow"

    // TODO: lockdown actions
    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.cost_and_usage.arn,
      "${aws_s3_bucket.cost_and_usage.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    // TODO: lockdown actions
    actions = [
      "glue:StartCrawler",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction",
    ]

    resources = [
      aws_lambda_function.csv_processor.arn,
    ]
  }
}

resource "aws_lambda_permission" "cost_and_usage" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.manifest_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.cost_and_usage.arn
}

resource "aws_sns_topic_subscription" "cost_and_usage" {
  topic_arn = aws_sns_topic.cost_and_usage.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.manifest_processor.arn
}

# ------------------------------------------------------------------------------
# csv processor lambda
# ------------------------------------------------------------------------------

data "aws_s3_bucket_object" "csv_processor" {
  bucket = var.source_bucket
  key    = "${var.source_path}/csv_processor.zip"
}

resource "aws_lambda_function" "csv_processor" {
  function_name     = "${var.name_prefix}-csv-processor-function"
  description       = "Lambda function."
  handler           = "lambda.lambda_handler"
  runtime           = "python2.7"
  memory_size       = "3008"
  timeout           = "300"
  s3_bucket         = data.aws_s3_bucket_object.csv_processor.bucket
  s3_key            = data.aws_s3_bucket_object.csv_processor.key
  s3_object_version = data.aws_s3_bucket_object.csv_processor.version_id
  role              = aws_iam_role.csv_processor.arn

  tags = var.tags
}

resource "aws_iam_role" "csv_processor" {
  name               = "${var.name_prefix}-csv-processor-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.csv_processor_assume.json
}

data "aws_iam_policy_document" "csv_processor_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "csv_processor" {
  name   = "${var.name_prefix}-csv-processor-lambda-privileges"
  role   = aws_iam_role.csv_processor.name
  policy = data.aws_iam_policy_document.csv_processor.json
}

data "aws_iam_policy_document" "csv_processor" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ListAllMyBuckets",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    effect = "Allow"

    // TODO: lockdown actions
    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.cost_and_usage.arn,
      "${aws_s3_bucket.cost_and_usage.arn}/*",
    ]
  }
}

