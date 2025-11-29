variable "queue_name" {
  description = "Name of the main SQS queue"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for tags"
  type        = string
}
