terraform {
  required_version = ">= 1.11"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
  }
}

# VAULT_ADDR, VAULT_CACERT and VAULT_TOKEN are supplied by the operator.
provider "vault" {}
