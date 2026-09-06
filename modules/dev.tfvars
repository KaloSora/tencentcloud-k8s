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
# It will only take master1 and node1 if enabled
k8s_cost_saving_mode = true

# Take master1 as the 1st control-plan since is_first_master = "true"
k8s_cluster = {
  "master1" = {instance_name = "k8s-master-1", cpu_core_count = 4, memory_size = 8, is_first_master = "true", tags = { "role" = "master", "purpose" = "master" }}
  "master2" = {instance_name = "k8s-master-2", cpu_core_count = 4, memory_size = 8, is_first_master = "", tags = { "role" = "master", "purpose" = "master" }}
  "master3" = {instance_name = "k8s-master-3", cpu_core_count = 4, memory_size = 8, is_first_master = "", tags = { "role" = "master", "purpose" = "master" }}
  "node1" = {instance_name = "k8s-node-1", cpu_core_count = 8, memory_size = 16, is_first_master = "", tags = { "role" = "worker", "purpose" = "devops" }}
  "node2" = {instance_name = "k8s-node-2", cpu_core_count = 8, memory_size = 16, is_first_master = "", tags = { "role" = "worker", "purpose" = "app" }}
  "node3" = {instance_name = "k8s-node-3", cpu_core_count = 8, memory_size = 16, is_first_master = "", tags = { "role" = "worker", "purpose" = "app" }}
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
helm_loki_version = "2.10.0"
helm_grafana_version = "8.6.0"
helm_grafana_url = "grafana.core.com"
helm_grafana_password = "Grafana12345"
helm_kube_prometheus_stack_version = "88.6.1"
