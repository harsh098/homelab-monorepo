variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "secret_reader_service_account_email" {
  type        = string
  description = "Service account used by the in-cluster GCP Secret Manager store"
  default     = "keycloak-secrets-sync@learninggcp-470023.iam.gserviceaccount.com"
}

variable "region" {
  type    = string
  default = "us-central1"
}
