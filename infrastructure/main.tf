terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    sqs     = "http://localhost:4566"
    s3      = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    # Add more services as needed, e.g.:
    # ec2     = "http://localhost:4566"
    # iam     = "http://localhost:4566"
  }
}

# Example modules - uncomment and customize for your app
# module "example_sqs" {
#   source = "./modules/sqs"
# 
#   queue_name   = "my-app-queue"
#   environment  = var.environment
#   project_name = var.project_name
# }
# 
# module "example_s3" {
#   source = "./modules/s3"
# 
#   bucket_name  = "my-app-bucket"
#   environment  = var.environment
#   project_name = var.project_name
# }
# 
# module "example_dynamodb" {
#   source = "./modules/dynamodb"
# 
#   table_name   = "my-app-table"
#   environment  = var.environment
#   project_name = var.project_name
# }
