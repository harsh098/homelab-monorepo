data "google_secret_manager_secret" "private_ca" {
  secret_id = var.private_ca_secret_id
}

