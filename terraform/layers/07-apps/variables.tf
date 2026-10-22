variable "cloudflare_account_id" {
  description = "Cloudflare account ID owning the Trilium tunnel."
  type        = string
  default     = "ce2c13dc20ba8de1db482e430b408fd5"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the Trilium hostname."
  type        = string
  default     = "c9e0a4d0e328d189813cd553dcda1bd7"
}

variable "trilium_hostname" {
  description = "Public fully qualified hostname for Trilium."
  type        = string
  default     = "trilium.hmx86.cloud"
}

variable "vault_token_file" {
  description = "Path to the temporary read-only OpenBao token minted for this run."
  type        = string
}
