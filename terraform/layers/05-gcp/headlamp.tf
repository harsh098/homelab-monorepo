# The current upstream release has a popup completion bug; keep the patched
# frontend image pullable when the single-node cluster is rebuilt.
resource "google_artifact_registry_repository" "headlamp" {
  project       = var.project_id
  location      = var.region
  repository_id = "homelab-headlamp"
  format        = "DOCKER"
  description   = "Headlamp with the upstream OIDC popup fix"

  docker_config {
    immutable_tags = true
  }
}

resource "google_artifact_registry_repository_iam_member" "headlamp_public_pull" {
  project    = var.project_id
  location   = google_artifact_registry_repository.headlamp.location
  repository = google_artifact_registry_repository.headlamp.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "allUsers"
}
