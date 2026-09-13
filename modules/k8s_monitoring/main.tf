locals {
  helm_default_timeout = 900
  monitoring_namespace = "monitoring"
  k8s_pss_version = "v${join(".", slice(split(".", var.k8s_version), 0, 2))}"
}

### PSA configuration for monitoring
resource "kubernetes_namespace" "monitoring_namespace" {
  metadata {
    name = local.monitoring_namespace

    labels = {
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version

      "pod-security.kubernetes.io/warn"  = "restricted"
      "pod-security.kubernetes.io/warn-version"  = local.k8s_pss_version
    }
  }
}

### Resource Quota for monitoring namespace
resource "kubernetes_resource_quota" "monitoring_quota" {

  metadata {
    name      = "monitoring-quota"
    namespace = kubernetes_namespace.monitoring_namespace.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "6"
      "requests.memory" = "10Gi"
      "limits.cpu"      = "12"
      "limits.memory"   = "20Gi"

      "pods"                   = "60"
      "persistentvolumeclaims" = "10"

      "requests.storage" = "500Gi"
      "${var.storage_class_name}.storageclass.storage.k8s.io/requests.storage" = "500Gi"
    }
  }
}

# Set default resource quota for containers in the monitoring namespace
resource "kubernetes_limit_range" "monitoring_limit_range" {
  metadata {
    name      = "monitoring-limit-range"
    namespace = kubernetes_namespace.monitoring_namespace.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = "500m"
        memory = "512Mi"
      }

      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

### Grafana & Loki Stack
resource "helm_release" "loki_stack" {

  depends_on = [
    kubernetes_resource_quota.monitoring_quota,
    kubernetes_limit_range.monitoring_limit_range
  ]

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_version
  namespace  = kubernetes_namespace.monitoring_namespace.metadata[0].name
  create_namespace = false
  timeout    = local.helm_default_timeout

  values = [
    templatefile(
      "${path.module}/helm_values/loki.yaml",
      {
        storage_class_name = var.storage_class_name
      }
    )
  ]
}

### kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {

  depends_on = [
    kubernetes_resource_quota.monitoring_quota, 
    kubernetes_limit_range.monitoring_limit_range
  ]

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version

  namespace        = kubernetes_namespace.monitoring_namespace.metadata[0].name
  create_namespace = false

  timeout = local.helm_default_timeout

  values = [
    templatefile(
      "${path.module}/helm_values/kube_prometheus_stack.yaml",
      {
        storage_class_name = var.storage_class_name
        grafana_password = var.grafana_password
        grafana_url = var.grafana_url
        monitoring_namespace = local.monitoring_namespace
      }
    )
  ]
}