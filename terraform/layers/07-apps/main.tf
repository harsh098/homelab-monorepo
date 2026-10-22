ephemeral "vault_kv_secret_v2" "cloudflare" {
  mount = "platform"
  name  = "apps/cloudflare"
}

module "trilium_ingress" {
  source         = "../../modules/public_ingress"
  account_id     = var.cloudflare_account_id
  zone_id        = var.cloudflare_zone_id
  hostname       = var.trilium_hostname
  origin_service = "http://trilium:8080"
}
