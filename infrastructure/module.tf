# This file makes the main infrastructure reusable as a module

# SQS Resources
resource "aws_sqs_queue" "counter_queue" {
  name = "counter-queue"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_sqs_queue" "counter_queue_dlq" {
  name = "counter-queue-dlq"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Variables for the module
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "simple-counter-app"
}

variable "app_image_uri" {
  description = "Docker image URI for the Rails application"
  type        = string
  default     = "localhost:5000/rails-counter-app:latest"
}

# Outputs
output "counter_queue_url" {
  description = "URL of the counter SQS queue"
  value       = aws_sqs_queue.counter_queue.url
}

output "counter_queue_name" {
  description = "Name of the counter SQS queue"
  value       = aws_sqs_queue.counter_queue.name
}

output "counter_queue_dlq_url" {
  description = "URL of the counter SQS DLQ"
  value       = aws_sqs_queue.counter_queue_dlq.url
}
