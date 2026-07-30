module "k8s-cfs" {
  source = "./k8s-cfs"
  availability_zone = var.cvm_availability_zone
  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  cfs_enabled = var.cfs_enabled
  cfs_cidr = var.cfs_allow_cidr
}