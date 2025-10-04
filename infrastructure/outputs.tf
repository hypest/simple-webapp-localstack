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

# ECR outputs removed - using local Docker registry for LocalStack
# Registry is available at localhost:5001 for LocalStack deployments

output "local_registry_url" {
  description = "URL of the local Docker registry (for LocalStack)"
  value       = "localhost:5001"
}

# SSH key outputs (marked as sensitive)
output "ssh_private_key" {
  description = "Private SSH key for EC2 access (save this to connect to instances)"
  value       = tls_private_key.rails_app.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "Public SSH key for EC2 access"
  value       = tls_private_key.rails_app.public_key_openssh
}
