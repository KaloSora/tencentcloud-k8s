module "k8s_cicd" {
  source                 = "./k8s_cicd"
  k8s_version            = var.k8s_version
  components             = var.cicd_components
  storage_class_name     = var.cfs_storage_class_name
  argocd_gitops_repo_url = var.argocd_gitops_repo_url
  gitops_credentials_id  = var.gitops_credentials_id
  gitops_github_token    = var.gitops_github_token

  depends_on = [module.k8s_cfs]
}
