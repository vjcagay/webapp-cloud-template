terraform {
  backend "s3" {
    bucket = "tf-remote-state-store"
    key    = "web-app-static-aws.tfstate"
    region = "ap-northeast-3"
  }

  required_version = "~>1.0.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.67.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-3"
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket        = "aws-webapp-infra"
  acl           = "private"
  force_destroy = true

  tags = {
    "Managed by Terraform" = "Yes"
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    "Version"   = "2012-10-17"
    "Id"        = "cloudfrontOAI"
    "Statement" = [
      {
        "Effect"    = "Allow"
        "Principal" = {
          "AWS" = aws_cloudfront_origin_access_identity.oai.iam_arn
        }
        "Action"    = "s3:*"
        "Resource"  = "${aws_s3_bucket.s3_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "aws-webapp-infra-cloudfront-oai"
}

resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.s3_bucket.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Managed by Terraform"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.s3_bucket.bucket

    forwarded_values {
      query_string = false

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = {
    "Managed by Terraform" = "Yes"
  }
}

output "s3_bucket" {
  value = aws_s3_bucket.s3_bucket.id
}

output "cloudfront_id" {
  value = aws_cloudfront_distribution.cloudfront.id
}