terraform {
  required_version = ">= 1.6.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
  # S3-compatible backend — connection details passed via backend.hcl at init time
  backend "s3" {}
}

provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config-homelab")
  config_context = "default"
}

# Create a namespace for each environment using the module
module "app_namespaces" {
  for_each = toset(var.environments)

  source = "./modules/namespace"

  name        = "app-${each.key}"
  environment = each.key
  app_name    = var.app_name

  # Scale limits by environment
  cpu_limit    = each.key == "prod" ? "4" : "2"
  memory_limit = each.key == "prod" ? "4Gi" : "2Gi"
}

# Shared ConfigMap for application configuration
resource "kubernetes_config_map_v1" "app_config" {
  for_each = toset(var.environments)

  metadata {
    name      = "${var.app_name}-config"
    namespace = "app-${each.key}"
  }

  data = {
    ENVIRONMENT = each.key
    LOG_LEVEL   = each.key == "prod" ? "info" : "debug"
    APP_NAME    = var.app_name
  }

  depends_on = [module.app_namespaces]
}

# Docker Hub image pull secret in each namespace
resource "kubernetes_secret_v1" "dockerhub" {
  for_each = toset(var.environments)

  metadata {
    name      = "dockerhub-credentials"
    namespace = "app-${each.key}"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          username = var.dockerhub_username
          password = var.dockerhub_token
          auth     = base64encode("${var.dockerhub_username}:${var.dockerhub_token}")
        }
      }
    })
  }

  depends_on = [module.app_namespaces]
}