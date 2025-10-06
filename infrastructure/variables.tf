variable "secret_key_base" {
  description = "(Optional) SECRET_KEY_BASE to set in the application environment. If empty, the instance will generate one at runtime.\nWARNING: Passing a secret here may store it in Terraform state. Use a secrets manager for production."
  type        = string
  default     = ""
  sensitive   = true
}
