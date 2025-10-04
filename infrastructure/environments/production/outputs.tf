output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

// ECR outputs removed for LocalStack Free compatibility. Restore if using real AWS ECR.

# Output from the SQS module
output "counter_queue_url" {
  description = "URL of the counter SQS queue"
  value       = module.sqs.counter_queue_url
}

output "counter_queue_name" {
  description = "Name of the counter SQS queue"
  value       = module.sqs.counter_queue_name
}
