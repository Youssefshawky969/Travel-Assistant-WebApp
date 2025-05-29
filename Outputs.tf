output "api_gateway_url" {
  value = aws_api_gateway_stage.stage.invoke_url
}

output "rest_api_id" {
  value = aws_api_gateway_rest_api.flask_lambda_api.id
}

output "s3_website_url" {
  value = aws_s3_bucket.frontend.website_endpoint
}