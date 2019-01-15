# ------------------------------------------------------------------------------
# S3 bucket
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "cost_and_usage" {
  bucket = "${var.report_bucket}"
  acl    = "private"

  tags = "${var.tags}"
}

resource "aws_s3_bucket_policy" "cost_and_usage" {
  bucket = "${aws_s3_bucket.cost_and_usage.id}"

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Id": "BILLINGACCOUNTPOLICY",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.aws_billing_account_id}:root"
      },
      "Action": [
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy"
      ],
      "Resource": "${aws_s3_bucket.cost_and_usage.arn}"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.aws_billing_account_id}:root"
      },
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "${aws_s3_bucket.cost_and_usage.arn}/*"
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_notification" "forward_bucket_notification" {
  bucket = "${aws_s3_bucket.cost_and_usage.id}"

  topic {
    topic_arn = "${aws_sns_topic.bucket_forwarder_topic.arn}"
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = ["aws_s3_bucket.cost_and_usage"]
}

# ------------------------------------------------------------------------------
# SNS
# ------------------------------------------------------------------------------

resource "aws_sns_topic" "bucket_forwarder_topic" {
  name = "${var.prefix}-topic"
}

resource "aws_sns_topic_policy" "default" {
  arn    = "${aws_sns_topic.bucket_forwarder_topic.arn}"
  policy = "${data.aws_iam_policy_document.bucket_forwarder_topic_policy.json}"
}

data "aws_iam_policy_document" "bucket_forwarder_topic_policy" {
  statement {
    actions = [
      "SNS:Publish",
    ]

    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"

      values = [
        "${aws_s3_bucket.cost_and_usage.arn}",
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "${aws_sns_topic.bucket_forwarder_topic.arn}",
    ]
  }
}

# ------------------------------------------------------------------------------
# Lambda function
# ------------------------------------------------------------------------------

data "aws_s3_bucket_object" "bucket_forwarder" {
  bucket = "${var.source_bucket}"
  key    = "${var.source_path}/bucket_forwarder.zip"
}

resource "aws_lambda_function" "bucket_forwarder" {
  function_name     = "${var.prefix}-bucket-forwarder-function"
  description       = "Lambda function."
  handler           = "lambda.lambda_handler"
  runtime           = "python2.7"
  memory_size       = 128
  timeout           = 300
  s3_bucket         = "${data.aws_s3_bucket_object.bucket_forwarder.bucket}"
  s3_key            = "${data.aws_s3_bucket_object.bucket_forwarder.key}"
  s3_object_version = "${data.aws_s3_bucket_object.bucket_forwarder.version_id}"
  role              = "${aws_iam_role.bucket_forwarder.arn}"

  environment {
    variables = {
      FORWARD_BUCKETS = "${join(",", var.destination_buckets)}"
    }
  }

  tags = "${var.tags}"
}

resource "aws_iam_role" "bucket_forwarder" {
  name               = "${var.prefix}-bucket-forwarder-lambda-role"
  assume_role_policy = "${data.aws_iam_policy_document.bucket_forwarder_assume.json}"
}

data "aws_iam_policy_document" "bucket_forwarder_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "bucket_forwarder" {
  name   = "${var.prefix}-bucket-forwarder-lambda-privileges"
  role   = "${aws_iam_role.bucket_forwarder.name}"
  policy = "${data.aws_iam_policy_document.bucket_forwarder.json}"
}

data "aws_iam_policy_document" "bucket_forwarder" {
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
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.cost_and_usage.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = "${formatlist("arn:aws:s3:::%s/*", var.destination_buckets)}"
  }
}

resource "aws_lambda_permission" "cost_and_usage" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.bucket_forwarder.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.bucket_forwarder_topic.arn}"
}

resource "aws_sns_topic_subscription" "cost_and_usage" {
  topic_arn = "${aws_sns_topic.bucket_forwarder_topic.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.bucket_forwarder.arn}"
}
