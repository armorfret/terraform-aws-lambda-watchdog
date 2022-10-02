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
  version = "0.2.1"

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
  arn  = "${module.apigw.execution_arn}/GET"
  rule = aws_cloudwatch_event_rule.scan.id

  http_target {
    path_parameter_values = ["scan"]
  }
}

resource "aws_cloudwatch_event_target" "scan" {
  rule      = aws_cloudwatch_event_rule.scan.name
  target_id = "invoke_hellolinodians"
  arn       = module.lambda.arn
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
