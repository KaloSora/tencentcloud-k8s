locals {
  helm_default_timeout = 900
  monitoring_namespace = "monitoring"
}

### Grafana & Loki Stack
resource "helm_release" "loki_stack" {

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_version
  namespace  = local.monitoring_namespace
  create_namespace = true
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
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version

  namespace        = local.monitoring_namespace
  create_namespace = true

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