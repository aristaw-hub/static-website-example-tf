# Configure the AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"  # Replace with your region
}

# S3 Bucket
resource "aws_s3_bucket" "static_bucket" {
  bucket = "aristas3tf.sctp-sandbox.com"  # Using your name from previous activity
  force_destroy = true
}

# Block Public Access - Setting to false to allow public access
resource "aws_s3_bucket_public_access_block" "enable_public_access" {
  bucket = aws_s3_bucket.static_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy - Allow public read access
resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.static_bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# IAM Policy Document for S3 bucket
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.static_bucket.arn}/*"
    ]
  }
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.static_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"  # Optional: if you have an error page
  }
}

# Route53 Zone (Data source - existing hosted zone)
data "aws_route53_zone" "sctp_zone" {
  name = "sctp-sandbox.com."
}

# Route53 Record - Alias to S3 website endpoint
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.sctp_zone.zone_id
  name    = "aristas3tf"  # Bucket prefix before sctp-sandbox.com
  type    = "A"

  alias {
    name                   = aws_s3_bucket_website_configuration.website.website_endpoint
    zone_id                = aws_s3_bucket.static_bucket.hosted_zone_id
    evaluate_target_health = false
  }
}

# Outputs
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.static_bucket.bucket
}

output "website_endpoint" {
  description = "S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "domain_name" {
  description = "Route53 domain name"
  value       = "http://${aws_route53_record.www.name}.sctp-sandbox.com"
}