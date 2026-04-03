variable "name" {
  description = "Namespace name"
  type        = string
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "cpu_limit" {
  description = "Total CPU limit for the namespace"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Total memory limit for the namespace"
  type        = string
  default     = "2Gi"
}