provider "aws" {
  region = "us-east-1"
}

resource "aws_lambda_function" "my_lambda" {
  filename         = "function.zip"
  function_name    = "my-lambda-function"
  role             = "arn:aws:iam::123456789012:role/lambda-role"
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  timeout          = 300
  memory_size      = 128
  source_code_hash = filebase64sha256("function.zip")
  
  environment {
    variables = {
      DB_PASSWORD = "mysecretpassword123"
      API_KEY     = "abcdef123456"
    }
  }
}

resource "aws_sqs_queue" "my_queue" {
  name                      = "my-queue"
  delay_seconds            = 0
  max_message_size         = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 0
  visibility_timeout_seconds = 30
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}
