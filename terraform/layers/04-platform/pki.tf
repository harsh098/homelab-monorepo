data "google_secret_manager_secret_version" "private_ca" {
  secret  = data.google_secret_manager_secret.private_ca.id
  version = "latest"
}

locals {
  private_ca_bundle          = jsondecode(data.google_secret_manager_secret_version.private_ca.secret_data)
  private_ca_certificate_pem = local.private_ca_bundle.ca_certificate_pem
  private_ca_private_key_pem = local.private_ca_bundle.ca_private_key_pem
  keycloak_tls_secret_name   = "${var.keycloak_hostname}-tls"
  openbao_tls_secret_name    = "${var.openbao_hostname}-tls"
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

  data_wo = {
    "tls.crt" = local.private_ca_certificate_pem
    "tls.key" = local.private_ca_private_key_pem
  }

  data_wo_revision = 1

  depends_on = [kubernetes_namespace_v1.cert_manager]
}

resource "kubernetes_manifest" "private_ca_cluster_issuer" {
  count = var.enable_cert_manager_issuance ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "homelab-private-ca"
    }
    spec = {
      ca = {
        secretName = kubernetes_secret_v1.cert_manager_ca.metadata[0].name
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_manifest" "keycloak_certificate" {
  count = var.enable_cert_manager_issuance ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "keycloak-platform-home-arpa"
      namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
    }
    spec = {
      secretName = local.keycloak_tls_secret_name
      issuerRef = {
        name  = kubernetes_manifest.private_ca_cluster_issuer[0].manifest.metadata.name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
      dnsNames = [var.keycloak_hostname]
      privateKey = {
        algorithm      = "ECDSA"
        rotationPolicy = "Always"
      }
      duration    = "2160h"
      renewBefore = "720h"
      usages      = ["digital signature", "key encipherment", "server auth"]
    }
  }

  depends_on = [kubernetes_manifest.private_ca_cluster_issuer]
}

resource "kubernetes_manifest" "openbao_certificate" {
  count = var.enable_cert_manager_issuance ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "openbao-platform-home-arpa"
      namespace = "openbao"
    }
    spec = {
      secretName = local.openbao_tls_secret_name
      issuerRef = {
        name  = kubernetes_manifest.private_ca_cluster_issuer[0].manifest.metadata.name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
      dnsNames = [var.openbao_hostname]
      privateKey = {
        algorithm      = "ECDSA"
        rotationPolicy = "Always"
      }
      duration    = "2160h"
      renewBefore = "720h"
      usages      = ["digital signature", "key encipherment", "server auth"]
    }
  }

  depends_on = [kubernetes_manifest.private_ca_cluster_issuer]
}
