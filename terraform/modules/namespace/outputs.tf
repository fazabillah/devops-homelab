output "namespace_name" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "service_account_name" {
  value = kubernetes_service_account_v1.app.metadata[0].name
}