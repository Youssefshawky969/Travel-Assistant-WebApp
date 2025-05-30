# Serverless Travel App

![Animation](https://github.com/user-attachments/assets/ee5dec18-5d1e-40aa-9931-97def6bbd785)


 ### Project Overview:
   This serverless travel assistant app enables users to input a city and receive live weather data and popular tourist destinations. It is fully deployed on AWS using Terraform for Infrastructure as Code (IaC).
 ### Purpose: 
 To build a fully serverless and globally accessible application that allows users to input a destination and receive live weather data and top tourist places. Uses static website hosting for frontend, with a dynamic backend powered by AWS Lambda and API Gateway, and secures content delivery using CloudFront and enforces CORS policies for browser-based communication.

## Steps
### Backend:
   #### Lambda Function
- AWS Lambda hosts the Python Flask backend that gets geo-coordinates using OpenStreetMap, fetches weather from Open-Meteo, then retrieves tourist places from Google Places API.
- Flask app is converted into an AWS Lambda-compatible handler using Mangum, and dependencies ```(flask, requests, flask-cors, etc.)``` are packaged with the app ``` places.py ```

   * This block ```Lambda Function``` deploys ```places.zip``` using ```python3.11```, defining handler, timeout, and source hash.
```
     resource "aws_lambda_function" "flask_lambda" {
  filename         = "places.zip"
  function_name    = "flask_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "places.handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = filebase64sha256("places.zip")

  
}
```
![image](https://github.com/user-attachments/assets/adf0c840-51af-49da-b00f-998cd5536f08)


* Creates a role for Lambda with ```sts:AssumeRole``` for ```lambda.amazonaws.com```
```
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}
```
![image](https://github.com/user-attachments/assets/12f6ad70-cf63-40c5-b4e2-d71ef0a48d9e)


* Policy Attachment grants Lambda basic execution permissions with AWS-managed policy.
```
resource "aws_iam_policy_attachment" "lambda_basic_execution" {
  name       = "lambda_basic_execution"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```
* API Gateway declares REST API with name and description.
```
resource "aws_api_gateway_rest_api" "flask_lambda_api" {
  name        = "flask_lambda_api"
  description = "API Gateway for Flask App"
}
```
*  Defines /get_city_info path within API Gateway.
```
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.flask_lambda_api.id
  parent_id   = aws_api_gateway_rest_api.flask_lambda_api.root_resource_id
  path_part   = "get_city_info"
}
```
![image](https://github.com/user-attachments/assets/7fc1fb0e-277b-4cab-9c6b-5e05b7c75712)


* HTTP Method is to allows ```GET``` method for readOnly.
  
```
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.flask_lambda_api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
}
```

* Lambda Integration is to connects API Gateway method to Lambda function with ```AWS_PROXY``` integration.

```
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.flask_lambda_api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.flask_lambda.invoke_arn
}
```
![image](https://github.com/user-attachments/assets/22097467-8e8a-41ed-bb19-0d7998665286)


* API Deployment is to triggers deployment of API Gateway configuration with lifecycle safety.

```
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
```
![image](https://github.com/user-attachments/assets/970b41b3-06ba-4562-8e89-e54d392de43d)


* Stage Creation exposes the API under /default stage.

```
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.flask_lambda_api.id
  stage_name    = "default"
}
```
![image](https://github.com/user-attachments/assets/a3d81009-7d4d-43a2-956a-bc1f936cabeb)



* Lambda Permission authorizes API Gateway to invoke the Lambda function securely.

```
resource "aws_lambda_permission" "apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.flask_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.flask_lambda_api.execution_arn}/*"
}
```
![image](https://github.com/user-attachments/assets/f1669743-45d2-46e2-a7dd-e8e506f4c238)


### Frontend

#### s3
- Creates a bucket for frontend static files, enables S3 to serve index.html as the root, restricts public ACLs and policies for security, then grants CloudFront OAC permission to access bucket content.

* Creates a bucket for frontend static files.
```
resource "aws_s3_bucket" "frontend" {
  bucket = "travel-frontend-bucket"

}
```
![image](https://github.com/user-attachments/assets/26145b68-dfd7-4bdd-b8e4-b53e96ea5648)


* Website Configuration enables S3 to serve ```index.html``` as the root.

```
resource "aws_s3_bucket_website_configuration" "frontend_site" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}
```
![image](https://github.com/user-attachments/assets/789189bd-8bb3-4e90-913e-4b0f69011fae)
![image](https://github.com/user-attachments/assets/4ac16e4d-5eb8-45b9-8b99-dfd41db5dada)



* Public Access restricts public ACLs and policies for security.

```
resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```
![image](https://github.com/user-attachments/assets/5192489d-f876-4005-858d-ae4857e29132)


* Bucket Policy grants CloudFront OAC permission to access bucket content.

```
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  
  depends_on = [aws_s3_bucket_public_access_block.allow_public]

policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend_cdn.arn
          }
        }
      }
    ]
  })
}
```
![image](https://github.com/user-attachments/assets/17569680-7b35-4662-9ac0-fa873e13f05f)


* HTML Templating:
  
  - Reads index.html from local path.
  
  ```
  data "local_file" "raw_html" {
  filename = "${path.module}/index.html"
  }
  ```
  

  - Replaces placeholder __API_URL__ with real API Gateway URL.

  ```
  locals {
  api_url = "https://${aws_api_gateway_rest_api.flask_lambda_api.id}.execute-api.us-east-1.amazonaws.com/default/get_city_info"
  rendered_html = replace(data.local_file.raw_html.content, "__API_URL__", local.api_url)
  }
  ```

  - Uploads updated HTML to S3 with appropriate content type.

  ```
  resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "index.html"
  content      = local.rendered_html
  content_type = "text/html; charset=utf-8"
  }
  ```

#### CloudFront
* CloudFront OAC generates Origin Access Control for secure S3 access.

```
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "frontend-s3-oac"
  description                       = "OAC for static website bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```
![image](https://github.com/user-attachments/assets/2b277f07-65a4-4a9c-abba-628970402102)


* CloudFront Distribution:
  - Connects to the S3 bucket.

  ```
  resource "aws_cloudfront_distribution" "frontend_cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }
  ```
  ![image](https://github.com/user-attachments/assets/9b4fdc17-e9a9-4c16-a155-660da945be3a)


  - Enables compression, caching, and redirection.

  ```
  default_cache_behavior {
    target_origin_id       = "s3-frontend-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  ```
  ![image](https://github.com/user-attachments/assets/bdac75f1-d6a3-42de-b5a4-56a6a1a5526c)


   - Secures delivery via HTTPS using the default CloudFront certificate.

   ```
   viewer_certificate {
    cloudfront_default_certificate = true
  }
   ```
### Terraform Deployment Steps
*  Install Terraform (if not already)
*  Set up your working directory
  - Make sure your .tf files include:
      - AWS provider
      - Lambda function
      - API Gateway
      - IAM roles
      - S3 bucket + policy
      - CloudFront configuration
      - Output blocks
* Make sure your AWS credentials are configured
  ```
  aws configure
  ```
* Run this in the folder where your .tf files are located
  ```
  terraform init
  ```
* Before applying, it's best to check what will be created
  ```
  terraform plan
  ```
* Deploy your resources
  ```
  terraform apply -auto-approve
  ```
* After a successful deployment, you’ll see values like:
  - API Gateway URL
  - CloudFront website URL
    ```
    Outputs:

    api_gateway_url = "https://abc123.execute-api.us-east-1.amazonaws.com/default/get_city_info"
    cloudfront_url  = "https://d3xyz123.cloudfront.net/index.html"
    ```

    ### Output:
![image](https://github.com/user-attachments/assets/482ff686-1c20-4953-8859-b411429b6f8f)
![image](https://github.com/user-attachments/assets/44b8e8d6-7a2e-4a66-b21b-27da1eb3d4b1)

* To clean everything up
  ```
  terraform destroy
  ```
