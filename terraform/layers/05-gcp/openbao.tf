# Initialization output is written out of band; never put unseal keys or the
# initial root token into Terraform state or Git.
resource "google_secret_manager_secret" "openbao_recovery" {
  secret_id           = "openbao-recovery"
  project             = var.project_id
  deletion_protection = true

  replication {
    auto {}
  }
}

resource "google_kms_key_ring" "openbao_unseal" {
  name     = "openbao-unseal-in"
  location = "asia-south1"
  project  = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "openbao_unseal" {
  name            = "openbao-unseal-in"
  key_ring        = google_kms_key_ring.openbao_unseal.id
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "openbao_unseal" {
  account_id   = "openbao-unseal"
  display_name = "OpenBao GCP KMS auto-unseal"
  project      = var.project_id
}

resource "google_project_iam_custom_role" "openbao_unseal" {
  role_id     = "openbaoKmsUnseal"
  title       = "OpenBao KMS unseal"
  description = "Only encrypt, decrypt, and inspect the OpenBao seal key"
  project     = var.project_id
  permissions = [
    "cloudkms.cryptoKeys.get",
    "cloudkms.cryptoKeyVersions.useToDecrypt",
    "cloudkms.cryptoKeyVersions.useToEncrypt",
  ]
}

resource "google_kms_crypto_key_iam_member" "openbao_unseal" {
  crypto_key_id = google_kms_crypto_key.openbao_unseal.id
  role          = google_project_iam_custom_role.openbao_unseal.id
  member        = "serviceAccount:${google_service_account.openbao_unseal.email}"
}

resource "google_service_account_key" "openbao_unseal" {
  service_account_id = google_service_account.openbao_unseal.name
}

resource "google_secret_manager_secret" "openbao_kms_credentials" {
  secret_id           = "openbao-kms-credentials"
  project             = var.project_id
  deletion_protection = true

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openbao_kms_credentials" {
  secret      = google_secret_manager_secret.openbao_kms_credentials.id
  secret_data = base64decode(google_service_account_key.openbao_unseal.private_key)
}

resource "google_secret_manager_secret_iam_member" "openbao_kms_credentials_reader" {
  project   = google_secret_manager_secret.openbao_kms_credentials.project
  secret_id = google_secret_manager_secret.openbao_kms_credentials.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.secret_reader_service_account_email}"
}
