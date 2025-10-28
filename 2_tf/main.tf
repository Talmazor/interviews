provider "aws" {
  region = var.region
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Lambda IAM Role with proper permissions
resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sqs" {
  name = "${local.name_prefix}-lambda-sqs-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name = "${local.name_prefix}-dlq"
  
  message_retention_seconds = var.sqs_message_retention_seconds
  tags = local.tags
}

# Main SQS Queue with DLQ configuration
resource "aws_sqs_queue" "main" {
  name = "${local.name_prefix}-queue"
  
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
  
  tags = local.tags
}

# Lambda Function with proper configuration
resource "aws_lambda_function" "main" {
  filename         = "function.zip"
  function_name    = "${local.name_prefix}-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  source_code_hash = filebase64sha256("function.zip")

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.main.url
    }
  }

  tags = local.tags
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 14
  tags              = local.tags
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "This metric monitors Lambda function errors"
  alarm_actions      = [] # Add SNS topic ARN for notifications

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  tags = local.tags
} 