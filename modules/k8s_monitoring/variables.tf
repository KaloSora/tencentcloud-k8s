variable "loki_version" {
  type = string
  description = "Loki version"
}

variable "grafana_version" {
  type = string
  description = "Grafana version"
}

variable "grafana_url" {
  type = string
  description = "Grafana URL"
}

variable "grafana_password" {
  type = string
  description = "Grafana admin password"
}

variable "kube_prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
}

variable "storage_class_name" {
  description = "Storage class name for persistent volumes"
  type        = string
}