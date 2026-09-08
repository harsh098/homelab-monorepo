resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = false
  wait             = true
  timeout          = 600

  set {
    name  = "installCRDs"
    value = "false"
  }
}

resource "kubernetes_manifest" "gcp_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "gcp-secret-manager"
    }
    spec = {
      provider = {
        gcpsm = {
          projectID = var.gcp_project_id
          auth = {
            secretRef = {
              secretAccessKeySecretRef = {
                name      = "gcp-secret-manager-reader"
                namespace = "external-secrets"
                key       = "credentials.json"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "kubernetes_manifest" "keycloak_google_oauth_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "keycloak-google-oauth"
      namespace = kubernetes_namespace_v1.keycloak.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = kubernetes_manifest.gcp_secret_store.manifest.metadata.name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "keycloak-google-oauth"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "client_id"
          remoteRef = {
            key      = "keycloak-google-oauth"
            property = "client_id"
          }
        },
        {
          secretKey = "client_secret"
          remoteRef = {
            key      = "keycloak-google-oauth"
            property = "client_secret"
          }
        },
      ]
    }
  }

  depends_on = [kubernetes_manifest.gcp_secret_store]
}
