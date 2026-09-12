module "k8s_ingress" {
  source = "./k8s_ingress"
  k8s_version = var.k8s_version
  ingress_nginx_version = var.helm_ingress_nginx_version
}