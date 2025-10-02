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
