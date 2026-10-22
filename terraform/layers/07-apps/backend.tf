terraform {
  backend "gcs" {
    bucket = "hmx-tf-bucket"
    prefix = "terraform/homelab/layers/07-apps"
  }
}
