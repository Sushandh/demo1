#############################################################
# Terraform AWS Static Website with Monitoring & Alerts
#############################################################

provider "aws" {
  region = "us-east-1" # Change this to your preferred region
}

#############################################################
# 1️⃣ Create S3 Bucket for Static Website
#############################################################
resource "aws_s3_bucket" "static_website" {
  bucket = "my-demo-bucket-001" # Change to a unique name
  acl    = "public-read"              # Public access for static website
  force_destroy = true                # Delete bucket even if it has objects

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# Allow public read access (required for static site)
resource "aws_s3_bucket_policy" "public_access" {
  bucket = aws_s3_bucket.static_website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}

#############################################################
# 2️⃣ Upload Website Files (HTML + Images)
#############################################################
# Example HTML file
resource "aws_s3_bucket_object" "index" {
  bucket       = aws_s3_bucket.static_website.id
  key          = "index.html"
  source       = "app/index.html"
  content_type = "text/html"
  acl          = "public-read"
}

# Example image file
resource "aws_s3_bucket_object" "image" {
  bucket       = aws_s3_bucket.static_website.id
  key          = "image.png"
  source       = "app/image.png"
  content_type = "image/png"
  acl          = "public-read"
}

#############################################################
# 3️⃣ SNS Topic for Email Alerts
#############################################################
resource "aws_sns_topic" "alerts" {
  name = "website-alerts"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "ktsushandh978@gmail.com" # Change to your email
}

#############################################################
# 4️⃣ Route53 Health Check
#############################################################
resource "aws_route53_health_check" "website_health" {
  fqdn              = aws_s3_bucket.static_website.website_endpoint
  type              = "HTTPS"
  port              = 443
  resource_path     = "/index.html"
  request_interval  = 30
  failure_threshold = 3
}

#############################################################
# 5️⃣ CloudWatch Alarm
#############################################################
resource "aws_cloudwatch_metric_alarm" "website_down_alarm" {
  alarm_name          = "WebsiteDownAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  statistic           = "Minimum"
  period              = 60
  threshold           = 0
  alarm_description   = "Triggered when website health check fails"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.website_health.id
  }
}

#############################################################
# 6️⃣ Outputs
#############################################################
output "website_url" {
  description = "The URL of the static website"
  value       = aws_s3_bucket.static_website.website_endpoint
}

output "sns_topic_arn" {
  description = "SNS topic ARN for email alerts"
  value       = aws_sns_topic.alerts.arn
}