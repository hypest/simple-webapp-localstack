variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "devcontainer-localstack"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}
