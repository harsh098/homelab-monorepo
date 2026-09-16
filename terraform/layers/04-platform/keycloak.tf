locals {
  keycloak_admin_username = "admin"

  # Recovery storage for the operator bootstrap credential. Keycloak remains the
  # system of record after the initial deployment.
  keycloak_admin_recovery_bundle = jsonencode({
    schema_version = 1
    username       = local.keycloak_admin_username
    password       = random_password.keycloak_admin.result
  })
}

resource "random_password" "keycloak_admin" {
  length           = 32
  special          = true
  override_special = "_%@-"
}


resource "kubernetes_manifest" "keycloak" {
  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "keycloak"
    }
  }
}
# Terraform owns only the namespace and bootstrap/recovery prerequisites. Flux
# owns the CNPG Cluster and OpenBao-backed ExternalSecret in GitOps.

resource "kubernetes_secret_v1" "keycloak_admin" {
  metadata {
    name      = "keycloak-operator-bootstrap"
    namespace = kubernetes_manifest.keycloak.manifest.metadata.name
  }

  type = "Opaque"

  data_wo = {
    username = local.keycloak_admin_username
    password = random_password.keycloak_admin.result
  }

  data_wo_revision = 1
}


resource "google_secret_manager_secret" "keycloak_admin_recovery" {
  secret_id = "keycloak-admin-recovery"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "keycloak_admin_recovery_initial" {
  secret          = google_secret_manager_secret.keycloak_admin_recovery.id
  secret_data     = local.keycloak_admin_recovery_bundle
  deletion_policy = "ABANDON"

  lifecycle {
    prevent_destroy = true
  }
}

