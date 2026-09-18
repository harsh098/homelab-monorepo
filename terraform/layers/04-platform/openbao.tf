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
