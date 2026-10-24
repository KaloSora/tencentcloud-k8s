region    = "ap-hongkong"
vpc_id    = "vpc-d7o9iy4y"
subnet_id = "subnet-adxnlxc5"

# SSH key variables - Absolute paths
ssh_key_private_key_path = "/Users/yihui.li/YIHUI/github_workspace/tencentcloud-k8s/modules/ssh_key/cvm_key.pem"
ssh_key_public_key_path  = "/Users/yihui.li/YIHUI/github_workspace/tencentcloud-k8s/modules/ssh_key/cvm_key.pub"

# CVM variables
cvm_availability_zone = "ap-hongkong-2"
cvm_charge_type       = "POSTPAID_BY_HOUR"
cvm_os_regex          = "^Rocky Linux 9\\.3"
cvm_login_user        = "root"

# K8s cluster variables
# It will only take master1 and node1 if enabled
k8s_cost_saving_mode = true

# Take master1 as the 1st control-plan since is_first_master = "true"
k8s_cluster = {
  "master1" = { instance_name = "k8s-master-1", cpu_core_count = 4, memory_size = 8, is_first_master = "true", tags = { "role" = "master", "purpose" = "master" } }
  "master2" = { instance_name = "k8s-master-2", cpu_core_count = 4, memory_size = 8, is_first_master = "", tags = { "role" = "master", "purpose" = "master" } }
  "master3" = { instance_name = "k8s-master-3", cpu_core_count = 4, memory_size = 8, is_first_master = "", tags = { "role" = "master", "purpose" = "master" } }
  "node1"   = { instance_name = "k8s-node-1", cpu_core_count = 8, memory_size = 16, is_first_master = "", tags = { "role" = "worker", "purpose" = "devops" } }
  "node2"   = { instance_name = "k8s-node-2", cpu_core_count = 8, memory_size = 16, is_first_master = "", tags = { "role" = "worker", "purpose" = "devops" } }
  "node3"   = { instance_name = "k8s-node-3", cpu_core_count = 8, memory_size = 16, is_first_master = "", tags = { "role" = "worker", "purpose" = "app" } }
}

### K8s config variables
k8s_helm_enabled        = true # Set to true to enable Helm plugin installation
k8s_cfssl_enabled       = true # Set to true to enable CFSSL plugin installation
k8s_version             = "1.28.8"
k8s_cidr                = "192.168.0.0/16"
k8s_cri_dockerd_version = "0.3.15"
k8s_cfssl_version       = "1.6.5"
k8s_helm_version        = "3.17.0"
k8s_kubeconfig_path     = "/Users/yihui.li/YIHUI/github_workspace/tencentcloud-k8s/modules/kubeconfig/config"

### Cloud file system variables
cfs_enabled            = true              # Set to true to enable CFS integration
cfs_allow_cidr         = "172.0.0.0/8"     # CFS access group CIDR, align with VPC CIDR. Here using default VPC CIDR
cfs_csi_secret         = "cfs-csi-api-key" # Hardcode the value since it's defined in "csi-provisioner-cfsplugin-new.yaml"
cfs_storage_class_name = "cfs-shared-storageclass"

### K8s CICD variables
helm_ingress_nginx_version         = "4.11.5"
helm_loki_version                  = "2.10.0"
helm_grafana_version               = "8.6.0"
helm_grafana_url                   = "grafana.core.com"
helm_grafana_password              = "Grafana12345"
helm_kube_prometheus_stack_version = "88.6.1"

argocd_gitops_repo_url = "https://github.com/KaloSora/tencentcloud-k8s-gitops.git"

# Jenkins promotion credential. Keep the committed token empty; supply the real
# value using a private -var-file loaded after dev.tfvars. Empty fails validation.
# Token is stored in state.
gitops_credentials_id = "gitops-github-token"

cicd_components = {
  harbor = {
    enabled         = true
    release_name    = "harbor"
    namespace       = "harbor"
    repository      = "https://helm.goharbor.io"
    chart           = "harbor"
    version         = "1.19.2"
    timeout         = 600
    atomic          = true
    wait            = true
    wait_for_jobs   = false
    value_templates = ["harbor.yaml"]
    config = {
      harbor_url      = "harbor.core.com"
      harbor_password = "Harbor12345"
    }
  }

  argocd = {
    enabled         = true
    release_name    = "argocd"
    namespace       = "argocd"
    repository      = "https://argoproj.github.io/argo-helm"
    chart           = "argo-cd"
    version         = "10.10.3"
    timeout         = 600
    atomic          = true
    wait            = true
    wait_for_jobs   = false
    value_templates = ["argocd.yaml"]
    config = {
      argocd_url            = "argocd.core.com"
      argocd_admin_password = "ArgoCD12345"
    }
  }

  jenkins = {
    enabled         = true
    release_name    = "jenkins"
    namespace       = "jenkins"
    repository      = "https://charts.jenkins.io"
    chart           = "jenkins"
    version         = "5.9.53"
    timeout         = 600
    atomic          = true
    wait            = true
    wait_for_jobs   = false
    value_templates = ["jenkins.yaml", "jenkins-controller.yaml"]
    config = {
      jenkins_url                      = "jenkins.core.com"
      jenkins_admin_username           = "admin"
      jenkins_admin_password           = "Jenkins12345"
      jenkins_pipeline_job_name        = "tencentcloud-k8s-app"
      jenkins_pipeline_scm_id          = "tencentcloud-k8s-app-git"
      jenkins_pipeline_repository_url  = "https://github.com/KaloSora/tencentcloud-k8s-app.git"
      jenkins_pipeline_script_path     = "ci/jenkins/Jenkinsfile"
      jenkins_pipeline_branch_includes = "JIRA-*"
      jenkins_pipeline_branch_excludes = ""
      jenkins_pipeline_scan_interval   = "5m"
      jenkins_promotion_job_name       = "tencentcloud-k8s-app-promotion"
      jenkins_promotion_scm_branch     = "*/main"
      jenkins_promotion_script_path    = "ci/jenkins/Jenkinsfile.promotion"
    }
  }

  plane = {
    enabled         = false
    release_name    = "plane"
    namespace       = "plane"
    repository      = "https://helm.plane.so/"
    chart           = "plane-ce"
    version         = "1.8.4"
    timeout         = 900
    atomic          = true
    wait            = true
    wait_for_jobs   = true
    value_templates = ["plane.yaml"]
    config = {
      plane_url            = "plane.core.com"
      plane_admin_email    = "admin@core.com"
      plane_admin_password = "Plane12345"
    }
  }
}
