# S3 Bucket for Frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "travel-frontend-bucket"

}

resource "aws_s3_bucket_website_configuration" "frontend_site" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}



# S3 Bucket Policy
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  
  depends_on = [aws_s3_bucket_public_access_block.allow_public]

policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}



# Upload index.html to S3



data "local_file" "raw_html" {
  filename = "${path.module}/index.html"
}

locals {
  api_url = "https://${aws_api_gateway_rest_api.flask_lambda_api.id}.execute-api.us-east-1.amazonaws.com/default/get_city_info"
  rendered_html = replace(data.local_file.raw_html.content, "__API_URL__", local.api_url)
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "index.html"
  content      = local.rendered_html
  content_type = "text/html; charset=utf-8"
}

