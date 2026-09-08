locals {
  keycloak_tls_secret_name = "${var.keycloak_hostname}-internal-tls"
  openbao_tls_secret_name  = "${var.openbao_hostname}-internal-tls"

  # UTF-8 JSON recovery bundle schema: schema_version, ca_certificate_pem,
  # and ca_private_key_pem. Secret Manager keeps this one-time backup; it is
  # not the certificate source used by cert-manager at runtime.
  private_ca_recovery_bundle = jsonencode({
    schema_version     = 1
    ca_certificate_pem = tls_self_signed_cert.private_ca.cert_pem
    ca_private_key_pem = tls_private_key.private_ca.private_key_pem
  })
}

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "kubernetes_secret_v1" "cert_manager_ca" {
  metadata {
    name      = "homelab-private-ca"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.private_ca.cert_pem
    "tls.key" = tls_private_key.private_ca.private_key_pem
  }
}

resource "tls_private_key" "private_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "private_ca" {
  private_key_pem = tls_private_key.private_ca.private_key_pem

  subject {
    common_name  = "Homelab Private CA"
    organization = "Homelab"
  }

  validity_period_hours = 87600
  is_ca_certificate     = true
  max_path_length       = 1
  set_authority_key_id  = true
  set_subject_key_id    = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "google_secret_manager_secret" "private_ca_recovery" {
  secret_id = "homelab-private-ca"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "private_ca_recovery_initial" {
  secret          = google_secret_manager_secret.private_ca_recovery.id
  secret_data     = local.private_ca_recovery_bundle
  deletion_policy = "ABANDON"

  # Secret versions are immutable. Do not replace the initial CA backup.
  lifecycle {
    prevent_destroy = true
  }
}

resource "tls_private_key" "keycloak" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "keycloak" {
  private_key_pem = tls_private_key.keycloak.private_key_pem
  dns_names       = [var.keycloak_hostname]

  subject {
    common_name  = var.keycloak_hostname
    organization = "Homelab"
  }
}

resource "tls_locally_signed_cert" "keycloak" {
  cert_request_pem   = tls_cert_request.keycloak.cert_request_pem
  ca_private_key_pem = tls_private_key.private_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.private_ca.cert_pem

  validity_period_hours = 2160
  early_renewal_hours   = 720


  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "tls_private_key" "openbao" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "openbao" {
  private_key_pem = tls_private_key.openbao.private_key_pem
  dns_names       = [var.openbao_hostname]

  subject {
    common_name  = var.openbao_hostname
    organization = "Homelab"
  }
}

resource "tls_locally_signed_cert" "openbao" {
  cert_request_pem   = tls_cert_request.openbao.cert_request_pem
  ca_private_key_pem = tls_private_key.private_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.private_ca.cert_pem

  validity_period_hours = 2160
  early_renewal_hours   = 720


  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_secret_v1" "keycloak_tls" {
  metadata {
    name      = local.keycloak_tls_secret_name
    namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_locally_signed_cert.keycloak.cert_pem
    "tls.key" = tls_private_key.keycloak.private_key_pem
  }
}

resource "kubernetes_secret_v1" "openbao_tls" {
  metadata {
    name      = local.openbao_tls_secret_name
    namespace = "openbao"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_locally_signed_cert.openbao.cert_pem
    "tls.key" = tls_private_key.openbao.private_key_pem
  }

}
