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

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.rails_app.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.rails_app.zone_id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.rails_app.name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.rails_app.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.rails_app.name
}
