variable "account_id" {
  description = "Cloudflare account ID that owns the tunnel."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID where the public hostname is registered."
  type        = string
}

variable "hostname" {
  description = "Fully qualified public hostname for this ingress."
  type        = string
}

variable "origin_service" {
  description = "Service URL reachable by cloudflared on its Compose network."
  type        = string
}
