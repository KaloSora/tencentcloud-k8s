terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

# Config Helm provider
provider "helm" {
  kubernetes {
    config_path = var.k8s_kubeconfig_path
  }
}

# Config K8s provider
provider "kubernetes" {
  config_path = var.k8s_kubeconfig_path
}