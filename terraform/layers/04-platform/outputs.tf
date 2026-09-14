
output "keycloak_admin_recovery_secret_name" {
  description = "GCP Secret Manager resource name holding the Keycloak bootstrap admin recovery bundle."
  value       = google_secret_manager_secret.keycloak_admin_recovery.name
}

output "keycloak_admin_recovery_secret_version" {
  description = "Initial immutable GCP Secret Manager version for the Keycloak bootstrap admin recovery bundle."
  value       = google_secret_manager_secret_version.keycloak_admin_recovery_initial.version
}

output "keycloak_ca_certificate_pem" {
  description = "Public Keycloak TLS CA certificate for OIDC clients and the K3s API server."
  value       = local.private_ca_certificate_pem
  sensitive   = true
}

