output "queue_url" {
  description = "URL of the main SQS queue"
  value       = aws_sqs_queue.this.url
}

output "dlq_url" {
  description = "URL of the DLQ"
  value       = aws_sqs_queue.dlq.url
}
