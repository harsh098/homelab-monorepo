terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.account_id
  name       = replace(var.hostname, ".", "-")
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = [
      {
        hostname = var.hostname
        service  = var.origin_service
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

module "dns_record" {
  source  = "../dns_record"
  zone_id = var.zone_id
  name    = var.hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  proxied = true
}

moved {
  from = cloudflare_dns_record.this
  to   = module.dns_record.cloudflare_dns_record.this
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared_config.this]
}
