terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

module "apigw" {
  source  = "armorfret/apigw-lambda/aws"
  version = "0.2.7"

  source_bucket  = var.lambda_bucket
  source_version = var.lambda_version
  function_name  = "watchdog_${var.data_bucket}"

  environment_variables = {
    S3_BUCKET = var.config_bucket
    S3_KEY    = "config.yaml"
  }

  stage_variables = {
    bucket = var.data_bucket
  }

  access_policy_document = data.aws_iam_policy_document.lambda_perms.json

  hostname = var.hostname
}

resource "aws_cloudwatch_event_rule" "scan" {
  name                = "watchdog_${var.config_bucket}_scan"
  description         = "Hit API Gateway"
  schedule_expression = "rate(${var.rate})"
}

resource "aws_cloudwatch_event_target" "scan" {
  arn  = "${module.apigw.execution_arn}/*/*"
  rule = aws_cloudwatch_event_rule.scan.id

  http_target {
    path_parameter_values = ["scan"]
  }

  retry_policy {
    maximum_event_age_in_seconds = 60
    maximum_retry_attempts       = 5
  }
}

module "publish_user" {
  source         = "armorfret/s3-publish/aws"
  version        = "0.2.4"
  logging_bucket = var.logging_bucket
  publish_bucket = var.data_bucket
}

module "config_user" {
  source         = "armorfret/s3-publish/aws"
  version        = "0.2.4"
  logging_bucket = var.logging_bucket
  publish_bucket = var.config_bucket
  count          = var.config_bucket == var.data_bucket ? 0 : 1
}

data "aws_iam_policy_document" "lambda_perms" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]

    resources = distinct([
      "arn:aws:s3:::${var.data_bucket}/*",
      "arn:aws:s3:::${var.data_bucket}",
      "arn:aws:s3:::${var.config_bucket}/*",
      "arn:aws:s3:::${var.config_bucket}",
    ])
  }

  statement {
    actions = [
      "s3:PutObject",
    ]

    resources = distinct([
      "arn:aws:s3:::${var.data_bucket}/*",
      "arn:aws:s3:::${var.data_bucket}",
    ])
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }
}

resource "aws_sns_topic" "this" {
  name = var.config_bucket
}

resource "aws_sns_topic_subscription" "this" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "runs" {
  alarm_name          = "${var.config_bucket}-runs"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Invocations"
  namespace           = "AWS/Events"
  period              = "7200"
  statistic           = "Maximum"
  threshold           = "1"

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.scan.id
  }

  alarm_description         = "Monitor for gaps in invocation of watchdog"
  alarm_actions             = [aws_sns_topic.this.arn]
  insufficient_data_actions = [aws_sns_topic.this.arn]
}

resource "aws_cloudwatch_metric_alarm" "fails" {
  alarm_name          = "${var.config_bucket}-fails"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Events"
  period              = "7200"
  statistic           = "Maximum"
  threshold           = "0"

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.scan.id
  }

  alarm_description         = "Monitor for fails in invocation of watchdog"
  alarm_actions             = [aws_sns_topic.this.arn]
  insufficient_data_actions = []
}
