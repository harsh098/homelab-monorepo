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
