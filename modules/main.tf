# Configure the TencentCloud Provider
provider "tencentcloud" {
  region     = var.region
  secret_id  = var.secret_id
  secret_key = var.secret_key
}

provider "helm" {
  kubernetes {
    config_path = var.k8s_kubeconfig_path
  }
}

# Config K8s provider
provider "kubernetes" {
  config_path = var.k8s_kubeconfig_path
}

terraform {
  required_version = "> 0.13.0"
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "1.81.5"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }

  # Configure remote state backend
  backend "cos" {
    prefix  = "cvm-backend/tfstate"
    encrypt = true
  }
}