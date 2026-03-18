terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = "supportdesk-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/supportdesk-backend"
  retention_in_days = 7
}

resource "aws_s3_bucket" "lambda_deployments" {
  bucket = "supportdesk-lambda-deployments-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_object" "backend_jar" {
  bucket = aws_s3_bucket.lambda_deployments.bucket
  key    = "supportdesk-backend.jar"
  source = var.jar_path
  etag   = filemd5(var.jar_path)  # forces Lambda update when jar changes
}

resource "aws_lambda_function" "backend" {
  function_name = "supportdesk-backend"
  role          = aws_iam_role.lambda.arn
  handler       = "com.supportdesk.LambdaHandler::handleRequest"
  runtime       = "java21"

  # S3 instead of direct upload
  s3_bucket = aws_s3_bucket.lambda_deployments.bucket
  s3_key    = aws_s3_object.backend_jar.key

  timeout     = 30
  memory_size = 1024

  snap_start {
    apply_on = "PublishedVersions"
  }

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE     = "prod"
      SPRING_DATASOURCE_URL      = "jdbc:postgresql://${var.db_url}/supportdesk?ssl=true&sslmode=require"
      SPRING_DATASOURCE_USERNAME = var.db_username
      SPRING_DATASOURCE_PASSWORD = var.db_password
      ALLOWED_ORIGINS              = var.allowed_origins
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}