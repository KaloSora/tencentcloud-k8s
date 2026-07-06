output "cfs_mount_ip" {
  value = var.cfs_enabled ? tencentcloud_cfs_file_system.k8s_cfs[0].mount_ip : ""
}