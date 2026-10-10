resource "random_password" "keycloak_db_password" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "keycloak_db_credentials" {
  secret_id = "keycloak-db-credentials"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "keycloak_db_credentials_reader" {
  project   = google_secret_manager_secret.keycloak_db_credentials.project
  secret_id = google_secret_manager_secret.keycloak_db_credentials.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.secret_reader_service_account_email}"
}

resource "google_secret_manager_secret_version" "keycloak_db_credentials" {
  secret = google_secret_manager_secret.keycloak_db_credentials.id
  secret_data = jsonencode({
    keycloak_db_username = "keycloak"
    keycloak_db_password = random_password.keycloak_db_password.result
  })
}
