#Create Origin Access Control for CloudFront

resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "frontend-s3-oac"
  description                       = "OAC for static website bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}