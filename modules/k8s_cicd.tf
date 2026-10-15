module "k8s_cicd" {
  source                             = "./k8s_cicd"
  k8s_version                        = var.k8s_version
  harbor_version                     = var.helm_harbor_version
  harbor_url                         = var.helm_harbor_url
  harbor_password                    = var.helm_harbor_password
  argocd_version                     = var.helm_argocd_version
  argocd_url                         = var.helm_argocd_url
  argocd_admin_password              = var.helm_argocd_admin_password
  jenkins_version                    = var.helm_jenkins_version
  jenkins_url                        = var.helm_jenkins_url
  jenkins_admin_username             = var.helm_jenkins_admin_username
  jenkins_admin_password             = var.helm_jenkins_admin_password
  jenkins_pipeline_repository_url    = var.jenkins_pipeline_repository_url
  jenkins_pipeline_repository_branch = var.jenkins_pipeline_repository_branch
  jenkins_pipeline_script_path       = var.jenkins_pipeline_script_path
  plane_enabled                      = var.plane_enabled
  plane_version                      = var.helm_plane_version
  plane_url                          = var.helm_plane_url
  plane_admin_email                  = var.helm_plane_admin_email
  plane_admin_password               = var.helm_plane_admin_password
  storage_class_name                 = var.cfs_storage_class_name

  depends_on = [module.k8s_cfs]
}
