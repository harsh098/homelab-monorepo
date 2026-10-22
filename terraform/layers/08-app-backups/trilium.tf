data "google_project" "current" {
  project_id = var.project_id
}

resource "google_kms_key_ring" "trilium_backups" {
  name     = "trilium-backups-in"
  location = "asia-south1"
  project  = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "trilium_backups" {
  name            = "trilium-backups-in"
  key_ring        = google_kms_key_ring.trilium_backups.id
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "trilium_backup_gcs_agent" {
  crypto_key_id = google_kms_crypto_key.trilium_backups.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_storage_bucket" "trilium_backups" {
  name                        = "hmx-trilium-backups-in"
  location                    = "asia-south1"
  project                     = var.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  encryption {
    default_kms_key_name = google_kms_crypto_key.trilium_backups.id
  }

  # Keep retention reversible until an isolated restore drill has succeeded.
  retention_policy {
    retention_period = 1209600
    is_locked        = false
  }

  soft_delete_policy {
    retention_duration_seconds = 1209600
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 90
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_kms_crypto_key_iam_member.trilium_backup_gcs_agent]
}

resource "google_service_account" "trilium_backup" {
  account_id   = "trilium-backup"
  display_name = "Trilium off-node backup writer"
  project      = var.project_id
}

# gcloud storage cp lists the destination bucket before a generation-guarded
# upload; no delete permission is needed by the backup or restore programs.
resource "google_project_iam_custom_role" "trilium_backup_writer" {
  role_id = "triliumBackupWriter"
  title   = "Trilium backup object writer and reader"
  project = var.project_id
  permissions = [
    "storage.buckets.get",
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

resource "google_storage_bucket_iam_member" "trilium_backup_writer" {
  bucket = google_storage_bucket.trilium_backups.name
  role   = google_project_iam_custom_role.trilium_backup_writer.id
  member = "serviceAccount:${google_service_account.trilium_backup.email}"
}

resource "google_service_account_key" "trilium_backup" {
  service_account_id = google_service_account.trilium_backup.name
}

# The private key stays in sensitive GCS-backed Terraform state and Secret Manager.
resource "google_secret_manager_secret" "trilium_backup_credentials" {
  secret_id           = "trilium-backup-gcs"
  project             = var.project_id
  deletion_protection = true

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "trilium_backup_credentials" {
  secret      = google_secret_manager_secret.trilium_backup_credentials.id
  secret_data = base64decode(google_service_account_key.trilium_backup.private_key)
}
