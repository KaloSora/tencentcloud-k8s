module "k8s_cicd" {
  source                 = "./k8s_cicd"
  k8s_version            = var.k8s_version
  components             = var.cicd_components
  storage_class_name     = var.cfs_storage_class_name
  argocd_gitops_repo_url = var.argocd_gitops_repo_url
  gitops_credentials_id  = var.gitops_credentials_id
  gitops_github_token    = var.gitops_github_token
  registry_nodes         = module.k8s_cvm.registry_nodes
  registry_ssh_user      = var.cvm_login_user
  registry_ssh_key_path  = var.ssh_key_private_key_path
  application_namespaces = module.k8s_app.namespace_names

  depends_on = [module.k8s_cfs, module.k8s_ingress]
}
