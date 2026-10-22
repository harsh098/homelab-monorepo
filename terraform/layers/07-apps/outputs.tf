output "trilium_tunnel_token" {
  description = "Cloudflared connector token for the Trilium Compose service."
  value       = module.trilium_ingress.tunnel_token
  sensitive   = true
}
