region = "ap-hongkong"
vpc_id = "vpc-d7o9iy4y"
subnet_id = "subnet-adxnlxc5"

# CVM variables
cvm_availability_zone = "ap-hongkong-2"
cvm_charge_type    = "POSTPAID_BY_HOUR"
cvm_os_regex       = "^Rocky Linux 9\\.3"
cvm_login_user     = "root"

# K8s cluster variables
k8s_cluster = {
  "master1" = {
    instance_name = "k8s-master-1", cpu_core_count = 4, memory_size = 8
  }
  "node1" = {
    instance_name = "k8s-node-1", cpu_core_count = 4, memory_size = 8
  }
  # "node2" = {
  #   instance_name = "k8s-node-2", cpu_core_count = 4, memory_size = 8
  # }
} 

### Cloud file system variables
cfs_enabled = false  # Set to true to enable CFS integration
cfs_allow_cidr = "172.0.0.0/8" # CFS access group CIDR
cfs_csi_secret = "cfs-csi-api-key" # Fix the value since it's defined in "csi-provisioner-cfsplugin-new.yaml"
# cfs_mount_point = "/opt/cfs_data/" # No need to define this variable since the CFS CSI driver will handle the mount point dynamically.