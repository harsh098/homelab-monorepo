resource "random_password" "backup_key" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "backup_encryption_key" {
  secret_id = "backup-encryption-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "backup_encryption_key_version" {
  secret      = google_secret_manager_secret.backup_encryption_key.id
  secret_data = random_password.backup_key.result
}

resource "google_secret_manager_secret" "backup_credentials" {
  secret_id = "backup-credentials"

  replication {
    auto {}
  }
}
resource "google_secret_manager_secret" "keycloak_google_oauth" {
  secret_id = "keycloak-google-oauth"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "openbao_unseal_key" {
  secret_id = "openbao-unseal-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "openbao_unseal_key_reader" {
  project   = google_secret_manager_secret.openbao_unseal_key.project
  secret_id = google_secret_manager_secret.openbao_unseal_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.secret_reader_service_account_email}"
}

resource "google_secret_manager_secret" "openbao_root_token" {
  secret_id = "openbao-root-token"

  replication {
    auto {}
  }
}
