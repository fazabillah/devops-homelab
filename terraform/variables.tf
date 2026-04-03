variable "environments" {
  description = "List of application environments to create namespaces for"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "app_name" {
  description = "Application name used for labeling resources"
  type        = string
  default     = "homelab-python-app"
}

variable "dockerhub_username" {
  description = "Docker Hub username for image pull secrets"
  type        = string
  sensitive   = true
}

variable "dockerhub_token" {
  description = "Docker Hub access token for image pull secrets"
  type        = string
  sensitive   = true
}