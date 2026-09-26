resource "random_password" "infisical_encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "infisical_auth_secret" {
  length  = 43
  special = false
}

resource "kubernetes_secret_v1" "infisical_secrets" {
  metadata {
    name      = "infisical-secrets"
    namespace = "infisical"
  }

  type = "Opaque"

  data = {
    ENCRYPTION_KEY = random_password.infisical_encryption_key.result
    AUTH_SECRET    = random_password.infisical_auth_secret.result
  }
}

resource "random_password" "infisical_postgresql" {
  length  = 32
  special = false
}

resource "random_password" "infisical_redis" {
  length  = 32
  special = false
}
resource "helm_release" "infisical" {
  name             = "infisical"
  repository       = "https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/"
  chart            = "infisical-standalone"
  version          = "1.11.0"
  namespace        = "infisical"
  create_namespace = true
  wait             = false
  timeout          = 900

  values = [
    yamlencode({
      infisical = {
        replicaCount = 2
      }
      postgresql = {
        enabled = true
        auth = {
          database = "infisicalDB"
          username = "infisical"
          password = random_password.infisical_postgresql.result
        }
        primary = {
          persistence = {
            enabled      = true
            size         = "20Gi"
            storageClass = "local-path"
          }
        }
      }
      redis = {
        enabled      = true
        architecture = "standalone"
        auth = {
          password = random_password.infisical_redis.result
        }
        master = {
          persistence = {
            enabled      = true
            size         = "5Gi"
            storageClass = "local-path"
          }
        }
      }
      ingress = {
        enabled          = true
        ingressClassName = "traefik"
        hostName         = var.infisical_hostname
        nginx            = { enabled = false }
        tls = [{
          secretName = local.infisical_tls_secret_name
          hosts      = [var.infisical_hostname]
        }]
      }
      ingress-nginx = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_secret_v1.infisical_secrets]
}
