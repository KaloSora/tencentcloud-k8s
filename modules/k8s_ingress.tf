module "k8s_ingress" {
  source = "./k8s_ingress"
  ingress_nginx_version = var.helm_ingress_nginx_version
}