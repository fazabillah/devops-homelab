resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.name
    labels = {
      environment  = var.environment
      app          = var.app_name
      managed-by   = "terraform"
    }
  }
}

resource "kubernetes_service_account_v1" "app" {
  metadata {
    name      = "${var.app_name}-sa"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app         = var.app_name
      environment = var.environment
    }
  }
}

resource "kubernetes_resource_quota_v1" "namespace_quota" {
  metadata {
    name      = "${var.name}-quota"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "1"
      "requests.memory" = "1Gi"
      "limits.cpu"      = var.cpu_limit
      "limits.memory"   = var.memory_limit
      "pods"            = "20"
    }
  }
}

resource "kubernetes_role_v1" "app_role" {
  metadata {
    name      = "${var.app_name}-role"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "app_role_binding" {
  metadata {
    name      = "${var.app_name}-role-binding"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.app_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.app.metadata[0].name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
}