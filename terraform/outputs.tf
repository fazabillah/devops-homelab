output "namespaces" {
  value = {
    for env in var.environments :
    env => module.app_namespaces[env].namespace_name
  }
  description = "Created namespace names by environment"
}

output "service_accounts" {
  value = {
    for env in var.environments :
    env => module.app_namespaces[env].service_account_name
  }
  description = "Service account names by environment"
}