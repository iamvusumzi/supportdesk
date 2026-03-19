resource "aws_iam_role" "consumer" {
  name = "supportdesk-consumer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "consumer_basic" {
  role       = aws_iam_role.consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow the consumer to read from SQS
resource "aws_iam_role_policy" "consumer_sqs" {
  name = "supportdesk-consumer-sqs-policy"
  role = aws_iam_role.consumer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = var.queue_arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "consumer" {
  name              = "/aws/lambda/supportdesk-ticket-router"
  retention_in_days = 7
}

# Package the Python function as a zip
data "archive_file" "consumer" {
  type        = "zip"
  source_dir  = var.source_path
  output_path = "${path.module}/consumer.zip"
  excludes = [ "requirements.txt", "layer" ]
}

data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "${var.source_path}/layer"
  output_path = "${path.module}/layer.zip"
}

resource "aws_lambda_layer_version" "psycopg2" {
  filename            = data.archive_file.layer.output_path
  layer_name          = "psycopg2-python312"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = data.archive_file.layer.output_base64sha256
}

resource "aws_lambda_function" "consumer" {
  function_name    = "supportdesk-ticket-router"
  role             = aws_iam_role.consumer.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.consumer.output_path
  source_code_hash = data.archive_file.consumer.output_base64sha256
  timeout          = 30
  memory_size      = 256
  layers = [aws_lambda_layer_version.psycopg2.arn]

  environment {
    variables = {
      DB_HOST     = split(":", var.db_url)[0]
      DB_PORT     = "5432"
      DB_NAME     = "supportdesk"
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
    }
  }

  depends_on = [aws_cloudwatch_log_group.consumer]
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = var.queue_arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = 1   # process one ticket at a time
  enabled          = true
}