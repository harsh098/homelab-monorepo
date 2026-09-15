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

