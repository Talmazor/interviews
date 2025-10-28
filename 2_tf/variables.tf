variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 30
}

variable "sqs_visibility_timeout" {
  description = "SQS visibility timeout in seconds"
  type        = number
  default     = 30
}

variable "sqs_message_retention_seconds" {
  description = "SQS message retention period in seconds"
  type        = number
  default     = 345600
}

variable "vpc_id" {
  description = "VPC ID for Lambda function"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda function"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda function"
  type        = list(string)
} 