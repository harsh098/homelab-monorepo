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
