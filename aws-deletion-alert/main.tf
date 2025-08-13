

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  trail_bucket_name = "deletion-alert-cloudtrail-logs-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = local.trail_bucket_name
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "expire-logs-365"
    enabled = true

    expiration {
      days = 365
    }
  }

  force_destroy = false
}

# Allow CloudTrail to write to bucket
resource "aws_s3_bucket_policy" "cloudtrail_put" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}"
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "main" {
  name                          = "account-wide-deletion-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = false
  enable_logging                = true
}

# SNS Topic for notifications
resource "aws_sns_topic" "deletion_alerts" {
  name = "aws-deletion-alerts"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.deletion_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# EventBridge rule to capture CloudTrail API calls whose eventName starts with Delete or Terminate
resource "aws_cloudwatch_event_rule" "deletion_events" {
  name        = "capture-deletion-api-calls"
  description = "Match CloudTrail API calls whose eventName starts with Delete or Terminate"

  event_pattern = jsonencode({
    "source" = ["aws.cloudtrail", "aws.ec2", "aws.rds", "aws.s3", "aws.lambda", "aws.iam", "aws.kms", "aws.elasticache", "aws.dynamodb", "aws.redshift", "aws.rds-data", "aws.eks"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    "detail" = {
      "eventName" = [
        { "prefix" = "Delete" },
        { "prefix" = "Terminate" }
      ]
    }
  })
}

# Target: SNS topic (raw event delivered as the message)
resource "aws_cloudwatch_event_target" "to_sns" {
  rule      = aws_cloudwatch_event_rule.deletion_events.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.deletion_alerts.arn
}

# Give EventBridge permission to publish to the SNS topic
resource "aws_sns_topic_policy" "allow_events_publish" {
  arn    = aws_sns_topic.deletion_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action = "sns:Publish"
        Resource = aws_sns_topic.deletion_alerts.arn
      }
    ]
  })
}

