# Preserve the encrypted restic archive and its KMS key after retiring the mail
# VM. Removing these resources would make existing backup snapshots unreadable.

resource "google_kms_key_ring" "mail_backups" {
  name     = "mail-backups-in"
  location = "asia-south1"
  project  = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "mail_backups" {
  name            = "mail-backups-in"
  key_ring        = google_kms_key_ring.mail_backups.id
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "mail_backup_gcs_service_agent" {
  crypto_key_id = google_kms_crypto_key.mail_backups.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_storage_bucket" "mail_backups" {
  name                        = "hmx-mail-backups-in"
  location                    = "asia-south1"
  project                     = var.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  encryption {
    default_kms_key_name = google_kms_crypto_key.mail_backups.id
  }

  # GCS must be able to use the key before configuring bucket default encryption.
  depends_on = [google_kms_crypto_key_iam_member.mail_backup_gcs_service_agent]

  lifecycle {
    prevent_destroy = true
  }
}

