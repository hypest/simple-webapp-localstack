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

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.rails_app.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.rails_app.name
}

# Output from the SQS module
output "counter_queue_url" {
  description = "URL of the counter SQS queue"
  value       = module.sqs.counter_queue_url
}

output "counter_queue_name" {
  description = "Name of the counter SQS queue"
  value       = module.sqs.counter_queue_name
}
