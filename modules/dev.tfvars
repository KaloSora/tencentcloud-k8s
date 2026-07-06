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
cfs_enabled = true