variable "host_lan_ip" {
  description = "LAN address on which Docker publishes AdGuard services."
  type        = string
  default     = "192.168.1.4"

  validation {
    condition     = can(cidrhost("${var.host_lan_ip}/32", 0))
    error_message = "host_lan_ip must be a valid IPv4 or IPv6 address."
  }
}

variable "k8s_ingress_ip" {
  description = "LAN address of the K3s/Traefik ingress endpoint."
  type        = string
  default     = "192.168.10.220"

  validation {
    condition     = can(cidrhost("${var.k8s_ingress_ip}/32", 0))
    error_message = "k8s_ingress_ip must be a valid IPv4 or IPv6 address."
  }
}

variable "image_tag" {
  description = "Verified AdGuard Home image version tag."
  type        = string
  default     = "v0.107.79"
}

variable "image_digest" {
  description = "Immutable digest for the AdGuard Home image."
  type        = string
  default     = "sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0"

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.image_digest))
    error_message = "image_digest must be a sha256 digest."
  }
}

variable "dns_domain" {
  description = "DNS suffix used by homelab rewrites."
  type        = string
  default     = "platform.home.arpa"
}

variable "dns_records" {
  description = "Additional AdGuard DNS rewrites. Supplied records override defaults."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for hostname, address in var.dns_records :
      can(regex("^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$", hostname))
    ])
    error_message = "dns_records keys must be non-empty hostnames."
  }

  validation {
    condition = alltrue([
      for _, address in var.dns_records :
      can(cidrhost("${address}/32", 0))
    ])
    error_message = "dns_records values must be valid IP addresses."
  }
}
