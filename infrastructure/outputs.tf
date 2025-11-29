# Generic outputs - add your own module outputs here

output "local_registry_url" {
  description = "URL of the local Docker registry (for ECR simulation)"
  value       = "localhost:5001"
}

# Example module outputs (uncomment when using modules)
# output "example_sqs_queue_url" {
#   value = module.example_sqs.queue_url
# }
#
# output "example_s3_bucket_name" {
#   value = module.example_s3.bucket_name
# }
#
# output "example_dynamodb_table_name" {
#   value = module.example_dynamodb.table_name
# }
