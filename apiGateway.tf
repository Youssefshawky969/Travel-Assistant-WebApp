#  Create API Gateway

resource "aws_api_gateway_rest_api" "flask_lambda_api" {
  name        = "flask_lambda_api"
  description = "API Gateway for Flask App"
}


# Create Resource
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.flask_lambda_api.id
  parent_id   = aws_api_gateway_rest_api.flask_lambda_api.root_resource_id
  path_part   = "get_city_info"
}

# Create HTTP Method
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.flask_lambda_api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Integrate with Lambda
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.flask_lambda_api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.flask_lambda.invoke_arn
}

# Deploy API
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.lambda]
  rest_api_id = aws_api_gateway_rest_api.flask_lambda_api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.flask_lambda_api))
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Create Stage
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.flask_lambda_api.id
  stage_name    = "default"
}


# Grant API Gateway Permission to Invoke Lambda
resource "aws_lambda_permission" "apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.flask_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.flask_lambda_api.execution_arn}/*"
}
