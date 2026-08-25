module "k8s_cicd" {
  source = "./k8s_cicd"
  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  ssh_key_private_key_path = var.ssh_key_private_key_path
  ssh_key_public_key_path = var.ssh_key_public_key_path
  cvm_login_user = var.cvm_login_user
  k8s_kubeconfig_path = var.k8s_kubeconfig_path
  k8s_master_public_ip = module.k8s_cvm.master_public_ip
  cfs_pgroup_id = module.k8s_cvm.cfs_pgroup_id
  ingress_nginx_version = var.helm_ingress_nginx_version
  harbor_version = var.helm_harbor_version
  harbor_url = var.helm_harbor_url
}