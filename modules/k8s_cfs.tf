module "k8s_cfs" {
  source = "./k8s_cfs"
  availability_zone = var.cvm_availability_zone
  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  cfs_cidr = var.cfs_allow_cidr
  cfs_storage_class_name = var.cfs_storage_class_name
}