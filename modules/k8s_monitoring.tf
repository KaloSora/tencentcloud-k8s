module "k8s_monitoring" {
  source = "./k8s_monitoring"
  loki_version = var.helm_loki_version
  grafana_version = var.helm_grafana_version
  grafana_url = var.helm_grafana_url
  grafana_password = var.helm_grafana_password
  kube_prometheus_stack_version = var.helm_kube_prometheus_stack_version
  storage_class_name = var.cfs_storage_class_name
}