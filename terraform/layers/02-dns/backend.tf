terraform {
  backend "gcs" {
    bucket = "hmx-tf-bucket"
    prefix = "terraform/homelab/layers/02-dns"
  }
}