module "k8s_app" {
  source      = "./k8s_app"
  k8s_version = var.k8s_version

  depends_on = [module.k8s_cvm]
}
