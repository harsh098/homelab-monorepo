data "google_secret_manager_secret_version" "openbao_root_token" {
  secret  = "openbao-root-token"
  version = "latest"
}

resource "kubernetes_secret_v1" "openbao_bootstrap_token" {
  metadata {
    name      = "openbao-bootstrap-token"
    namespace = "external-secrets"
  }

  type = "Opaque"

  data = {
    token = data.google_secret_manager_secret_version.openbao_root_token.secret_data
  }
}

// OpenBao runs in standalone persistent-storage mode; dev mode is explicitly
// disabled. Terraform injects the recovery/bootstrap token from GCP so Flux's
// declarative bootstrap Job can configure Kubernetes auth after redeployments.
resource "kubernetes_secret_v1" "openbao_bootstrap_ca" {
  metadata {
    name      = "openbao-bootstrap-ca"
    namespace = "external-secrets"
  }

  type = "Opaque"

  data = {
    "ca.crt" = local.private_ca_certificate_pem
  }
}
resource "random_password" "openbao_external_secrets_token" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret" "openbao_external_secrets_token" {
  secret_id = "openbao-external-secrets-token"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openbao_external_secrets_token" {
  secret      = google_secret_manager_secret.openbao_external_secrets_token.id
  secret_data = random_password.openbao_external_secrets_token.result
}

resource "kubernetes_secret_v1" "openbao_external_secrets_token" {
  metadata {
    name      = "openbao-external-secrets-token"
    namespace = "external-secrets"
  }

  type = "Opaque"

  data = {
    token = random_password.openbao_external_secrets_token.result
  }
}
resource "random_password" "openbao_pushsecret_token" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret" "openbao_pushsecret_token" {
  secret_id = "openbao-pushsecret-token"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openbao_pushsecret_token" {
  secret      = google_secret_manager_secret.openbao_pushsecret_token.id
  secret_data = random_password.openbao_pushsecret_token.result
}

resource "kubernetes_secret_v1" "openbao_pushsecret_token" {
  metadata {
    name      = "openbao-pushsecret-token"
    namespace = "external-secrets"
  }

  type = "Opaque"

  data = {
    token = random_password.openbao_pushsecret_token.result
  }
}
resource "helm_release" "openbao" {
  name             = "openbao"
  repository       = "https://openbao.github.io/openbao-helm"
  chart            = "openbao"
  version          = "0.29.3"
  namespace        = "openbao"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      ui = {
        enabled = true
      }
      server = {
        dev = {
          enabled = false
        }
        standalone = {
          enabled = true
          config  = <<-EOT
            ui = true

            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"
            }

            storage "file" {
              path = "/openbao/data"
            }
          EOT
        }
        dataStorage = {
          enabled      = true
          size         = "10Gi"
          storageClass = "local-path"
          accessMode   = "ReadWriteOnce"
        }
        persistentVolumeClaimRetentionPolicy = {
          whenDeleted = "Retain"
          whenScaled  = "Retain"
        }
        readinessProbe = {
          enabled             = true
          path                = "/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200"
          port                = 8200
          failureThreshold    = 2
          initialDelaySeconds = 5
          periodSeconds       = 5
          successThreshold    = 1
          timeoutSeconds      = 3
        }
        ingress = {
          enabled          = true
          ingressClassName = "traefik"
          hosts = [
            {
              host = var.openbao_hostname
            }
          ]
          tls = [
            {
              secretName = local.openbao_tls_secret_name
              hosts      = [var.openbao_hostname]
            }
          ]
        }
      }
    })
  ]
}
