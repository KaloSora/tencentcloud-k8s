# Create CFS access group
resource "tencentcloud_cfs_access_group" "k8s_cfs_ag" {
  name        = "k8s-cfs-ag"
  description = "Allow K8s cluster nodes to access"
}

# Create standard CFS file system
resource "tencentcloud_cfs_file_system" "k8s_cfs" {
  count = var.cfs_enabled ? 1 : 0
  
  name              = "k8s-nfs-shared-storage"
  availability_zone = var.availability_zone
  access_group_id   = tencentcloud_cfs_access_group.k8s_cfs_ag.id
  storage_type      = "SD" # SD / HP
  protocol          = "NFS"
  vpc_id            = var.vpc_id
  subnet_id         = var.subnet_id
}