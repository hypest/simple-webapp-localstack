# Use the modules from the parent directory
module "sqs" {
  source = "../.."
}

// ECR repository removed for LocalStack Free compatibility.
// Restore terraform resources here when deploying to real AWS.

