module "k8s-cvm" {
  source = "./k8s-cvm"
  cvm_availability_zone = var.cvm_availability_zone
  cvm_charge_type = var.cvm_charge_type
  cvm_login_user = var.cvm_login_user
  cvm_os_regex = var.cvm_os_regex
  k8s_cluster = var.k8s_cluster
  cvm_cfs_enabled = var.cfs_enabled
  cvm_cfs_ip = module.k8s-cfs.cfs_mount_ip
  cvm_cfs_mount_point = var.cfs_mount_point
}