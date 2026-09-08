output "private_ca_certificate" {
  description = "PEM-encoded root certificate to install in clients that access the private ingresses."
  value       = tls_self_signed_cert.private_ca.cert_pem
}

output "private_ca_secret_name" {
  description = "GCP Secret Manager resource name holding the private CA recovery bundle."
  value       = google_secret_manager_secret.private_ca_recovery.name
}

output "private_ca_secret_version" {
  description = "Initial immutable GCP Secret Manager version for the private CA recovery bundle."
  value       = google_secret_manager_secret_version.private_ca_recovery_initial.version
}

output "keycloak_admin_recovery_secret_name" {
  description = "GCP Secret Manager resource name holding the Keycloak bootstrap admin recovery bundle."
  value       = google_secret_manager_secret.keycloak_admin_recovery.name
}

output "keycloak_admin_recovery_secret_version" {
  description = "Initial immutable GCP Secret Manager version for the Keycloak bootstrap admin recovery bundle."
  value       = google_secret_manager_secret_version.keycloak_admin_recovery_initial.version
}

output "cert_manager_namespace" {
  description = "Namespace containing cert-manager and its CA input Secret."
  value       = kubernetes_namespace_v1.cert_manager.metadata[0].name
}

output "cert_manager_ca_secret_name" {
  description = "Kubernetes TLS Secret cert-manager will use as a future CA Issuer input."
  value       = kubernetes_secret_v1.cert_manager_ca.metadata[0].name
}
