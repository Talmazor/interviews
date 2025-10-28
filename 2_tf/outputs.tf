output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "sqs_queue_url" {
  description = "URL of the main SQS queue"
  value       = aws_sqs_queue.main.url
}

output "sqs_queue_arn" {
  description = "ARN of the main SQS queue"
  value       = aws_sqs_queue.main.arn
}

output "dlq_queue_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_role.arn
} 