resource "random_password" "infisical_db_password" {
  length  = 32
  special = false
}

resource "random_password" "infisical_encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "infisical_auth_secret" {
  length  = 43
  special = false
}

resource "google_storage_bucket" "infisical_backups" {
  name                        = "hmx-infisical-backups"
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  lifecycle_rule {
    condition {
      age = 2
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_service_account" "infisical_backup" {
  account_id   = "infisical-backup"
  display_name = "Infisical database backup"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "infisical_backup_writer" {
  bucket = google_storage_bucket.infisical_backups.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.infisical_backup.email}"
}

resource "google_storage_hmac_key" "infisical_backup" {
  service_account_email = google_service_account.infisical_backup.email
  project               = var.project_id
}

resource "google_service_account_key" "infisical_backup" {
  service_account_id = google_service_account.infisical_backup.name
}

resource "google_secret_manager_secret" "infisical_bootstrap" {
  secret_id = "infisical-bootstrap"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "infisical_bootstrap_reader" {
  project   = google_secret_manager_secret.infisical_bootstrap.project
  secret_id = google_secret_manager_secret.infisical_bootstrap.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.secret_reader_service_account_email}"
}

resource "google_secret_manager_secret_version" "infisical_bootstrap" {
  secret = google_secret_manager_secret.infisical_bootstrap.id
  secret_data = jsonencode({
    encryption_key       = random_password.infisical_encryption_key.result
    auth_secret          = random_password.infisical_auth_secret.result
    db_username          = "infisical"
    db_password          = random_password.infisical_db_password.result
    db_connection_uri    = "postgresql://infisical:${random_password.infisical_db_password.result}@infisical-db-rw.infisical.svc.cluster.local:5432/infisical"
    backup_bucket        = google_storage_bucket.infisical_backups.name
    backup_access_key    = google_storage_hmac_key.infisical_backup.access_id
    backup_secret_key    = google_storage_hmac_key.infisical_backup.secret
    service_account_json = base64decode(google_service_account_key.infisical_backup.private_key)
  })
}
