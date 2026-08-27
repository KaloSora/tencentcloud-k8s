region = "ap-hongkong"
vpc_id = "vpc-d7o9iy4y"
subnet_id = "subnet-adxnlxc5"

# SSH key variables - Absolute paths
ssh_key_private_key_path = "/Users/yihui.li/YIHUI/github_workspace/tencentcloud-k8s/modules/ssh_key/cvm_key.pem"
ssh_key_public_key_path = "/Users/yihui.li/YIHUI/github_workspace/tencentcloud-k8s/modules/ssh_key/cvm_key.pub"

# CVM variables
cvm_availability_zone = "ap-hongkong-2"
cvm_charge_type    = "POSTPAID_BY_HOUR"
cvm_os_regex       = "^Rocky Linux 9\\.3"
cvm_login_user     = "root"

# K8s cluster variables
k8s_cluster = {
  "master1" = {
    instance_name = "k8s-master-1", cpu_core_count = 4, memory_size = 8, tags = { "role" = "master", "purpose" = "master" }
  }
  "node1" = {
    instance_name = "k8s-node-1", cpu_core_count = 4, memory_size = 8, tags = { "role" = "worker", "purpose" = "devops" }
  }
  # "node2" = {
  #   instance_name = "k8s-node-2", cpu_core_count = 4, memory_size = 8, tags = { "role" = "worker", "purpose" = "app" }
  # }
}

### K8s config variables
k8s_helm_enabled = true  # Set to true to enable Helm plugin installation
k8s_cfssl_enabled = true  # Set to true to enable CFSSL plugin installation
k8s_version = "1.28.8"
k8s_cidr = "192.168.0.0/16"
k8s_cri_dockerd_version = "0.3.15"
k8s_cfssl_version = "1.6.5"
k8s_helm_version="3.17.0"
k8s_kubeconfig_path = "/Users/yihui.li/YIHUI/github_workspace/tencentcloud-k8s/modules/kubeconfig/config"

### Cloud file system variables
cfs_enabled = true  # Set to true to enable CFS integration
cfs_allow_cidr = "172.0.0.0/8" # CFS access group CIDR, align with VPC CIDR. Here using default VPC CIDR
cfs_csi_secret = "cfs-csi-api-key" # Hardcode the value since it's defined in "csi-provisioner-cfsplugin-new.yaml"

### K8s CICD variables
helm_ingress_nginx_version = "4.11.5"
helm_harbor_version = "1.19.2"
helm_harbor_url = "harbor.core.com"
helm_harbor_password = "Harbor12345"

