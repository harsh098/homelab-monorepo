terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

resource "cloudflare_dns_record" "this" {
  zone_id = var.zone_id
  name    = var.name
  type    = var.type
  content = var.content
  proxied = var.proxied
  ttl     = var.ttl
}
