# This file makes the main infrastructure reusable as a module

# Variables for the module
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "simple-counter-app"
}

variable "app_image_uri" {
  description = "Docker image URI for the Rails application"
  type        = string
  default     = "localhost:5001/rails-counter-app:latest"
}
