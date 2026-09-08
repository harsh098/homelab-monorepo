# Variables for 04-apps layer

variable "gcp_project_id" {
  description = "GCP project that stores the private CA recovery secret."
  type        = string
  default     = "learninggcp-470023"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "gcp_project_id must be a valid GCP project ID."
  }
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

variable "keycloak_postgresql_storage_size" {
  description = "Persistent volume size for the single-node Keycloak PostgreSQL database."
  type        = string
  default     = "8Gi"

  validation {
    condition     = can(regex("^[1-9][0-9]*(Mi|Gi|Ti)$", var.keycloak_postgresql_storage_size))
    error_message = "keycloak_postgresql_storage_size must be a Kubernetes quantity in Mi, Gi, or Ti."
  }
}

variable "openbao_hostname" {
  description = "Hostname used by the OpenBao ingress."
  type        = string
  default     = "openbao.platform.home.arpa"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.openbao_hostname))
    error_message = "openbao_hostname must be a valid lowercase DNS hostname."
  }
}