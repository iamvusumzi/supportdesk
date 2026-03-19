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

resource "aws_iam_role_policy" "lambda_sqs_publish" {
  name = "supportdesk-lambda-sqs-publish"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = var.sqs_queue_arn
    }]
  })
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
  source_hash = filesha256(var.jar_path) # Lambda update when jar changes
}

resource "aws_lambda_function" "backend" {
  function_name = "supportdesk-backend"
  role          = aws_iam_role.lambda.arn
  handler       = "com.supportdesk.LambdaHandler::handleRequest"
  runtime       = "java21"

  s3_bucket = aws_s3_bucket.lambda_deployments.bucket
  s3_key    = aws_s3_object.backend_jar.key

  source_code_hash = filesha256(var.jar_path)

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
      SQS_QUEUE_URL                = var.sqs_queue_url
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}