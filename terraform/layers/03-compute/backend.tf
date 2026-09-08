terraform {
  backend "gcs" {
    bucket = "hmx-tf-bucket"
    prefix = "terraform/homelab/rebuild/layers/03-compute"
  }
}