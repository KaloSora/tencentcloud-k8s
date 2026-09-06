# Create CFS access group
resource "tencentcloud_cfs_access_group" "k8s_cfs_ag" {
  name        = "k8s-cfs-ag"
  description = "Allow K8s cluster nodes to access"
}

# CFS Access rules for each CVM private IP
resource "tencentcloud_cfs_access_rule" "k8s_cfs_rule" {

  access_group_id = tencentcloud_cfs_access_group.k8s_cfs_ag.id
  auth_client_ip  = var.cfs_cidr
  priority        = 1
  rw_permission   = "RW"
  user_permission = "no_all_squash"
}

resource "kubernetes_storage_class" "cfs_shared" {

  metadata {
    name = var.cfs_storage_class_name
  }

  storage_provisioner = "com.tencent.cloud.csi.cfs"
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"

  mount_options = [
    "vers=3",
    "nolock",
    "proto=tcp",
    "noresvport"
  ]

  parameters = {
    vpcId       = var.vpc_id
    subnetId    = var.subnet_id
    storageType = "SD"
    pgroupid    = tencentcloud_cfs_access_group.k8s_cfs_ag.id
  }
}