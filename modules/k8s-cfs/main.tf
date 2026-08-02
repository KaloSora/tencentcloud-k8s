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

# Remove this part since we are using the CFS CSI driver to manage CFS file systems dynamically, 
# Instead of creating a static CFS file system in Terraform. The CFS CSI driver will handle the creation and management of CFS file systems as needed by the K8s cluster.
# Create standard CFS file system
# resource "tencentcloud_cfs_file_system" "k8s_cfs" {
#   count = var.cfs_enabled ? 1 : 0
  
#   name              = "k8s-nfs-shared-storage"
#   availability_zone = var.availability_zone
#   access_group_id   = tencentcloud_cfs_access_group.k8s_cfs_ag.id
#   storage_type      = "SD" # SD / HP
#   protocol          = "NFS"
#   vpc_id            = var.vpc_id
#   subnet_id         = var.subnet_id
# }