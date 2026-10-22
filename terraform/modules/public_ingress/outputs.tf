output "tunnel_token" {
  description = "Token for a cloudflared connector to this remotely managed tunnel."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  sensitive   = true
}
