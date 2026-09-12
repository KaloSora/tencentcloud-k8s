locals {
  helm_default_timeout = 600
  harbor_namespace = "harbor"
  k8s_pss_version = "v${join(".", slice(split(".", var.k8s_version), 0, 2))}"
}

### PSA configuration for monitoring
resource "kubernetes_namespace" "harbor_namespace" {
  metadata {
    name = local.harbor_namespace

    labels = {
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version

      "pod-security.kubernetes.io/warn"  = "restricted"
      "pod-security.kubernetes.io/warn-version"  = local.k8s_pss_version
    }
  }
}

### Harbor
resource "helm_release" "harbor" {

  name             = "harbor"
  repository       = "https://helm.goharbor.io"
  chart            = "harbor"
  version          = var.harbor_version
  namespace        = kubernetes_namespace.harbor_namespace.metadata[0].name
  create_namespace = false
  timeout          = local.helm_default_timeout

  values = [
    templatefile(
      "${path.module}/helm_values/harbor.yaml", 
      {
        harbor_url     = var.harbor_url
        harbor_password = var.harbor_password
        storage_class  = var.storage_class_name
      }
    )
  ]
}


