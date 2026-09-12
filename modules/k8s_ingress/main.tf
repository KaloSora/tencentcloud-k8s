locals {
  helm_default_timeout = 300
  ingress_namespace = "ingress-nginx"
  k8s_pss_version = "v${join(".", slice(split(".", var.k8s_version), 0, 2))}"
}

# resource "tencentcloud_clb_instance" "k8s_clb" {
#   clb_name = "k8s_clb"
#   network_type = "OPEN"
#   # charge_type = "POSTPAID_BY_HOUR"
#   internet_charge_type = "TRAFFIC_POSTPAID_BY_HOUR"
#   internet_bandwidth_max_out = 10
#   vpc_id    = var.vpc_id
#   subnet_id = var.subnet_id
# }

### PSA configuration for ingress-nginx
resource "kubernetes_namespace" "ingress_nginx_namespace" {
  metadata {
    name = local.ingress_namespace

    labels = {
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version

      "pod-security.kubernetes.io/warn"  = "restricted"
      "pod-security.kubernetes.io/warn-version"  = local.k8s_pss_version
    }
  }
}

### Set ingress-nginx service type to ClusterIP
### This is to avoid the issue of LoadBalancer service type to pending status and stuck terraform provider
### Health check: http://NodeIP:10254/healthz
resource "helm_release" "ingress_nginx" {

  name             = "ingress-nginx"
  namespace        = kubernetes_namespace.ingress_nginx_namespace.metadata[0].name
  create_namespace = false
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  timeout          = local.helm_default_timeout

  wait             = true # Wait until all resources are in a ready state before marking the release as successful

  values = [
    file("${path.module}/helm_values/ingress-nginx.yaml")
  ]
}