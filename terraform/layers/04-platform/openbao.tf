resource "helm_release" "openbao" {
  name             = "openbao"
  repository       = "https://openbao.github.io/openbao-helm"
  chart            = "openbao"
  namespace        = "openbao"
  create_namespace = true

  set {
    name  = "server.dev.enabled"
    value = "true"
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "traefik"
  }

  set {
    name  = "server.ingress.hosts[0].host"
    value = var.openbao_hostname
  }

  set {
    name  = "server.ingress.tls[0].secretName"
    value = local.openbao_tls_secret_name
  }

  set {
    name  = "server.ingress.tls[0].hosts[0]"
    value = var.openbao_hostname
  }

}
