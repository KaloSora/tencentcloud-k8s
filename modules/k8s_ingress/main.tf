locals {
  helm_default_timeout = 300
}

# resource "tencentcloud_clb_instance" "k8s_clb" {
#   clb_name = "my-pay-as-you-go-clb"
#   network_type = "OPEN"
#   # charge_type = "POSTPAID_BY_HOUR"
#   internet_charge_type = "TRAFFIC_POSTPAID_BY_HOUR"
#   internet_bandwidth_max_out = 10
#   vpc_id    = var.vpc_id
#   subnet_id = var.subnet_id
# }

### Set ingress-nginx service type to ClusterIP
### This is to avoid the issue of LoadBalancer service type to pending status and stuck terraform provider
### Health check: http://NodeIP:10254/healthz
resource "helm_release" "ingress_nginx" {

  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  timeout          = local.helm_default_timeout

  values = [
    file("${path.module}/helm_values/ingress-nginx.yaml")
  ]
}