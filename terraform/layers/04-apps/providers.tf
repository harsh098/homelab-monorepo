terraform {
  required_version = ">= 1.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
  }
}

provider "kubernetes" {
  config_path = "${path.module}/../03-compute/kubeconfig"
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/../03-compute/kubeconfig"
  }
}

provider "google" {
  project = var.gcp_project_id
}