module "k8s_cicd" {
  source = "./k8s_cicd"
  k8s_version = var.k8s_version
  harbor_version = var.helm_harbor_version
  harbor_url = var.helm_harbor_url
  harbor_password = var.helm_harbor_password
  storage_class_name = var.cfs_storage_class_name
}