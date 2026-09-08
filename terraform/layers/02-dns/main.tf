locals {
  managed_data_dir = abspath("${path.module}/adguard-managed")
  config_file      = "${local.managed_data_dir}/AdGuardHome.yaml"
  config_dir       = "${local.managed_data_dir}/conf"
  work_dir         = "${local.managed_data_dir}/work"
  default_dns_records = {
    "adguard.${var.dns_domain}"  = var.host_lan_ip
    "openbao.${var.dns_domain}"  = var.k8s_ingress_ip
    "keycloak.${var.dns_domain}" = var.k8s_ingress_ip
    "traefik.${var.dns_domain}"  = var.k8s_ingress_ip
  }
  dns_records = merge(local.default_dns_records, var.dns_records)
}

resource "local_file" "adguard_config" {
  content = yamlencode({
    http = {
      address     = "0.0.0.0:80"
      session_ttl = "720h"
    }
    users          = []
    auth_attempts  = 5
    block_auth_min = 15
    language       = ""
    theme          = "auto"
    dns = {
      bind_hosts    = ["0.0.0.0"]
      port          = 53
      upstream_dns  = []
      fallback_dns  = []
      enable_dnssec = true
    }
    filters           = []
    whitelist_filters = []
    user_rules        = []
    filtering = {
      rewrites_enabled = true
      rewrites = [
        for domain, answer in local.dns_records : {
          domain  = domain
          answer  = answer
          enabled = true
        }
      ]
      filtering_enabled = true
    }
    querylog = {
      enabled = true
    }
    statistics = {
      enabled = true
    }
    tls = {
      enabled = false
    }
    schema_version = 34
  })
  filename = local.config_file
}

resource "docker_image" "adguard" {
  name         = "adguard/adguardhome:${var.image_tag}@${var.image_digest}"
  keep_locally = true
}

resource "docker_container" "adguardhome" {
  name     = "adguardhome"
  image    = docker_image.adguard.image_id
  restart  = "unless-stopped"
  hostname = "adguardhome"
  capabilities {
    add = ["CAP_NET_ADMIN", "CAP_NET_BIND_SERVICE", "CAP_NET_RAW"]
  }

  ports {
    internal = 53
    external = 53
    ip       = var.host_lan_ip
    protocol = "tcp"
  }

  ports {
    internal = 53
    external = 53
    ip       = var.host_lan_ip
    protocol = "udp"
  }

  ports {
    internal = 80
    external = 80
    ip       = var.host_lan_ip
    protocol = "tcp"
  }

  ports {
    internal = 3000
    external = 3000
    ip       = var.host_lan_ip
    protocol = "tcp"
  }

  entrypoint = ["/bin/sh", "-c"]
  command = [
    "cp /seed/AdGuardHome.yaml /opt/adguardhome/conf/AdGuardHome.yaml && exec /opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work"
  ]

  volumes {
    host_path      = local.config_file
    container_path = "/seed/AdGuardHome.yaml"
    read_only      = true
  }

  volumes {
    host_path      = local.config_dir
    container_path = "/opt/adguardhome/conf"
    read_only      = false
  }

  volumes {
    host_path      = local.work_dir
    container_path = "/opt/adguardhome/work"
    read_only      = false
  }

  working_dir = "/opt/adguardhome/work"

  lifecycle {
    replace_triggered_by = [local_file.adguard_config]
  }
  depends_on = [local_file.adguard_config]
}

