output "cfs_access_group_id" {
  description = "CFS access group ID (PGroupId)"
  value       = tencentcloud_cfs_access_group.k8s_cfs_ag.id
}