variable "zone_id" {
  description = "Cloudflare zone containing the record."
  type        = string
}

variable "name" {
  description = "DNS record name (fully qualified hostname)."
  type        = string
}

variable "type" {
  description = "DNS record type, such as A, AAAA, CNAME, or TXT."
  type        = string
}

variable "content" {
  description = "Value of the DNS record."
  type        = string
}

variable "proxied" {
  description = "Proxy supported record types through Cloudflare."
  type        = bool
  default     = false
}

variable "ttl" {
  description = "Record TTL in seconds; 1 selects Cloudflare automatic TTL."
  type        = number
  default     = 1
}
