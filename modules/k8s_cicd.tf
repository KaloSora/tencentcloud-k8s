module "k8s_cicd" {
  source             = "./k8s_cicd"
  k8s_version        = var.k8s_version
  components         = var.cicd_components
  storage_class_name = var.cfs_storage_class_name

  depends_on = [module.k8s_cfs]
}
