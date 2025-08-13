
output "s3_cloudtrail_bucket" {
  value = aws_s3_bucket.cloudtrail_logs.bucket
}

output "sns_topic_arn" {
  value = aws_sns_topic.deletion_alerts.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.deletion_events.name
}