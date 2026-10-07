resource "random_password" "infisical_redis" {
  length  = 32
  special = false
}

resource "kubernetes_manifest" "infisical" {
  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "infisical"
    }
  }
}

resource "kubernetes_secret_v1" "infisical_redis_values" {
  metadata {
    name      = "infisical-redis-values"
    namespace = kubernetes_manifest.infisical.manifest.metadata.name
  }

  data_wo = {
    "values.yaml" = yamlencode({
      redis = {
        auth = {
          password = random_password.infisical_redis.result
        }
      }
    })
  }
  data_wo_revision = 1
}

