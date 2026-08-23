module "k8s-cicd" {
  source = "./k8s-cicd"
  ssh_key_private_key_path = var.ssh_key_private_key_path
  ssh_key_public_key_path = var.ssh_key_public_key_path
  cvm_login_user = var.cvm_login_user
  k8s_master_public_ip = module.k8s-cvm.master_public_ip
  ingress_nginx_version = var.ingress_nginx_version
}