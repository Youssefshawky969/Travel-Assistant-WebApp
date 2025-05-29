# Upload Lambda Function
resource "aws_lambda_function" "flask_lambda" {
  filename         = "places.zip"
  function_name    = "flask_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "places.handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = filebase64sha256("places.zip")

  
}