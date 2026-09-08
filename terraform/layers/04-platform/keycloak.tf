locals {
  keycloak_admin_username = "admin"

  # UTF-8 JSON recovery bundle for the bootstrap credential. Secret Manager is
  # recovery storage only; Keycloak remains the system of record after init.
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
    name      = "keycloak-admin"
    namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
  }

  type = "Opaque"

  data_wo = {
    password = random_password.keycloak_admin.result
  }

  data_wo_revision = 1
}

resource "kubernetes_secret_v1" "keycloak_postgresql" {
  metadata {
    name      = "keycloak-postgresql"
    namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
  }

  type = "Opaque"

  data_wo = {
    "postgres-password" = random_password.keycloak_postgresql_admin.result
    password            = random_password.keycloak_postgresql_user.result
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

  # Secret versions are immutable. Do not replace the initial admin backup.
  lifecycle {
    prevent_destroy = true
  }
}

resource "helm_release" "keycloak" {
  name             = "keycloak"
  chart            = "https://charts.bitnami.com/bitnami/keycloak-25.2.0.tgz"
  namespace        = kubernetes_namespace_v1.keycloak.metadata[0].name
  create_namespace = false
  upgrade_install  = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    auth = {
      adminUser         = local.keycloak_admin_username
      existingSecret    = kubernetes_secret_v1.keycloak_admin.metadata[0].name
      passwordSecretKey = "password"
    }

    image = {
      repository = "bitnamilegacy/keycloak"
      tag        = "26.3.3-debian-12-r0"
    }


    production                   = true
    proxyHeaders                 = "xforwarded"
    hostnameStrict               = true
    httpEnabled                  = true
    replicaCount                 = 1
    automountServiceAccountToken = false

    cache = {
      enabled = false
    }

    extraEnvVars = [
      {
        name  = "KC_CACHE_CONFIG_FILE"
        value = "cache-ispn.xml"
      }
    ]

    resourcesPreset = "none"
    resources = {
      requests = {
        cpu    = "250m"
        memory = "512Mi"
      }
      limits = {
        cpu    = "1000m"
        memory = "1Gi"
      }
    }

    ingress = {
      enabled          = true
      ingressClassName = "traefik"
      hostname         = var.keycloak_hostname
      path             = "/"
      servicePort      = "http"
      tls              = true
      selfSigned       = false
      extraTls = [
        {
          hosts      = [var.keycloak_hostname]
          secretName = local.keycloak_tls_secret_name
        }
      ]
    }

    postgresql = {
      enabled = true
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
        repository = "bitnamilegacy/postgresql"
        tag        = "17.6.0-debian-12-r0"
      }

      architecture = "standalone"
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
    }
  })]

  depends_on = [
    kubernetes_secret_v1.keycloak_admin,
    kubernetes_secret_v1.keycloak_postgresql,
    kubernetes_manifest.keycloak_certificate,
  ]
}
