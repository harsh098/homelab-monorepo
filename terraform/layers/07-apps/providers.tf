terraform {
  required_version = ">= 1.11"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# The playbook supplies the path to a 30-minute read-only token file.
# TLS uses the existing homelab CA; no root token reaches Terraform.
provider "vault" {
  address          = "https://openbao.platform.home.arpa"
  ca_cert_file     = pathexpand("~/.config/homelab/keycloak-ca.crt")
  skip_child_token = true

  auth_login_token_file {
    filename = var.vault_token_file
  }
}

provider "cloudflare" {
  api_token = ephemeral.vault_kv_secret_v2.cloudflare.data["api_token"]
}
