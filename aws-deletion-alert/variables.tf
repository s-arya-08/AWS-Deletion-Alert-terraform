variable "aws_region" {
  type    = string
  default = "us-east-1"
  description = "Region to create the supporting resources (CloudTrail is multi-region regardless)."
}

variable "notification_email" {
  type        = string
  description = "Email address to receive deletion alerts. Subscription needs confirmation."
}
