# Credentials are added out of band by tools/bootstrap-tekton-dashboard-auth.py.
# Terraform manages only the secret container and its in-cluster reader grant.
resource "google_secret_manager_secret" "tekton_dashboard_basic_auth" {
  secret_id = "tekton-dashboard-basic-auth"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "tekton_dashboard_basic_auth_reader" {
  project   = google_secret_manager_secret.tekton_dashboard_basic_auth.project
  secret_id = google_secret_manager_secret.tekton_dashboard_basic_auth.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.secret_reader_service_account_email}"
}
