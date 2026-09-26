# Variables for 04-platform layer

variable "gcp_project_id" {
  description = "GCP project that stores the private CA recovery secret."
  type        = string
  default     = "learninggcp-470023"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be a valid GCP project ID."
  }
}
variable "private_ca_secret_id" {
  description = "Existing Google Secret Manager secret to retain."
  type        = string
  default     = "homelab-private-ca"
}
variable "enable_cert_manager_issuance" {
  description = "Enable cert-manager CA issuer and application certificates."
  type        = bool
  default     = true
}




variable "keycloak_hostname" {
  description = "Hostname used by the Keycloak ingress."
  type        = string
  default     = "keycloak.platform.home.arpa"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.keycloak_hostname))
    error_message = "keycloak_hostname must be a valid lowercase DNS hostname."
  }
}


variable "infisical_hostname" {
  description = "Hostname used by the Infisical ingress."
  type        = string
  default     = "infisical.platform.home.arpa"
}
