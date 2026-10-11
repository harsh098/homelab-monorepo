locals {
  platform_backups = {
    openbao  = "hmx-openbao-backups-in"
    keycloak = "hmx-keycloak-backups-in"
  }
}

resource "google_kms_key_ring" "platform_backups" {
  name     = "platform-backups-in"
  location = "asia-south1"
  project  = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "platform_backups" {
  for_each        = local.platform_backups
  name            = "${each.key}-backups-in"
  key_ring        = google_kms_key_ring.platform_backups.id
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "platform_backup_gcs_agent" {
  for_each      = local.platform_backups
  crypto_key_id = google_kms_crypto_key.platform_backups[each.key].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_storage_bucket" "platform_backups" {
  for_each                    = local.platform_backups
  name                        = each.value
  location                    = "asia-south1"
  project                     = var.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  encryption {
    default_kms_key_name = google_kms_crypto_key.platform_backups[each.key].id
  }

  # No irreversible retention lock before completing an isolated restore drill.
  retention_policy {
    retention_period = 1209600
    is_locked        = false
  }

  # Barman replaces backup.info during a backup; keep every replaced generation
  # protected by retention rather than allowing an overwrite to erase it.
  versioning {
    enabled = each.key == "keycloak"
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

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      with_state                 = "ARCHIVED"
      num_newer_versions         = 1
      days_since_noncurrent_time = 90
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_kms_crypto_key_iam_member.platform_backup_gcs_agent]
}

resource "google_service_account" "platform_backups" {
  for_each     = local.platform_backups
  account_id   = "${each.key}-backup"
  display_name = "${each.key} off-node backup writer"
  project      = var.project_id
}

# OpenBao never replaces objects; the Barman writer must replace backup.info.
resource "google_project_iam_custom_role" "platform_backup_writer" {
  role_id = "platformBackupWriter"
  title   = "Platform backup object writer"
  project = var.project_id
  permissions = [
    "storage.buckets.get",
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

resource "google_storage_bucket_iam_member" "platform_backup_writer" {
  for_each = local.platform_backups
  bucket   = google_storage_bucket.platform_backups[each.key].name
  role     = each.key == "keycloak" ? google_project_iam_custom_role.keycloak_barman_writer.id : google_project_iam_custom_role.platform_backup_writer.id
  member   = "serviceAccount:${google_service_account.platform_backups[each.key].email}"
}

resource "google_project_iam_custom_role" "keycloak_barman_writer" {
  role_id = "keycloakBarmanBackupWriter"
  title   = "Keycloak Barman cloud backup writer"
  project = var.project_id
  permissions = [
    "storage.buckets.get",
    "storage.multipartUploads.abort",
    "storage.multipartUploads.create",
    "storage.multipartUploads.listParts",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

resource "google_service_account_key" "platform_backups" {
  for_each           = local.platform_backups
  service_account_id = google_service_account.platform_backups[each.key].name
}

# Bootstrap credentials remain available if K3s and OpenBao are both unavailable.
# Private keys reside in sensitive Terraform state and Secret Manager, not Git.
resource "google_secret_manager_secret" "platform_backup_credentials" {
  for_each            = local.platform_backups
  secret_id           = "${each.key}-backup-gcs"
  project             = var.project_id
  deletion_protection = true

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "platform_backup_credentials" {
  for_each    = local.platform_backups
  secret      = google_secret_manager_secret.platform_backup_credentials[each.key].id
  secret_data = base64decode(google_service_account_key.platform_backups[each.key].private_key)
}

resource "google_secret_manager_secret_iam_member" "platform_backup_credentials_reader" {
  for_each  = local.platform_backups
  project   = google_secret_manager_secret.platform_backup_credentials[each.key].project
  secret_id = google_secret_manager_secret.platform_backup_credentials[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.secret_reader_service_account_email}"
}
