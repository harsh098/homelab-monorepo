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

resource "random_password" "keycloak_postgresql_admin" {
  length           = 32
  special          = true
  override_special = "_%@-"
}

resource "random_password" "keycloak_postgresql_user" {
  length           = 32
  special          = true
  override_special = "_%@-"
}

resource "kubernetes_namespace_v1" "keycloak" {
  metadata {
    name = "keycloak"
  }
}

resource "kubernetes_secret_v1" "keycloak_admin" {
  metadata {
    name      = "keycloak-operator-bootstrap"
    namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
  }

  type = "Opaque"

  data_wo = {
    username = local.keycloak_admin_username
    password = random_password.keycloak_admin.result
  }

  data_wo_revision = 1
}

resource "kubernetes_secret_v1" "keycloak_postgresql" {
  metadata {
    name      = "keycloak-db-credentials"
    namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
  }

  type = "Opaque"

  data_wo = {
    username          = "keycloak"
    password          = random_password.keycloak_postgresql_user.result
    postgres-password = random_password.keycloak_postgresql_admin.result
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

# The operator requires an external PostgreSQL database. This is intentionally
# a new release and PVC name; the old embedded Bitnami Keycloak/PostgreSQL
# resources are not reused during this destructive migration.
resource "helm_release" "keycloak_postgresql" {
  name             = "keycloak-db"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "postgresql"
  version          = "16.7.21"
  namespace        = kubernetes_namespace_v1.keycloak.metadata[0].name
  create_namespace = false
  upgrade_install  = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    fullnameOverride = "keycloak-db"
    architecture     = "standalone"

    auth = {
      existingSecret = kubernetes_secret_v1.keycloak_postgresql.metadata[0].name
      username       = "keycloak"
      database       = "keycloak"
      secretKeys = {
        adminPasswordKey = "postgres-password"
        userPasswordKey  = "password"
      }
    }

    image = {
      repository = "bitnami/postgresql"
      tag        = "17.6.0-debian-12-r0"
    }

    primary = {
      persistence = {
        enabled = true
        size    = var.keycloak_postgresql_storage_size
      }
      resourcesPreset = "none"
      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    }
  })]

  depends_on = [
    kubernetes_secret_v1.keycloak_postgresql,
  ]
}
