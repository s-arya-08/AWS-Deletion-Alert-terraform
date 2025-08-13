# Terraform configuration: AWS-wide resource-deletion alerting
# What this creates:
# - S3 bucket for CloudTrail logs
# - CloudTrail (multi-region, management events)
# - SNS topic + email subscription
# - EventBridge rule that matches Delete*/Terminate* CloudTrail API calls
# - EventBridge target: SNS topic (sends the raw CloudTrail event JSON to email)
#
# Note: After `terraform apply`, you MUST confirm the subscription from the email you provide.
#
# Usage:
# 1. Set the variable `notification_email` to the address that should get alerts.
# 2. terraform init && terraform apply
# 3. Confirm subscription in the email inbox.