output "master_public_ip" {
  description = "Public IP of the master node"
  value       = try(tencentcloud_instance.k8s_server["master1"].public_ip, null)
}

output "instance_id" {
  description = "vm instance id"
  value       = tencentcloud_instance.k8s_server[0].id
}

output "private_ips" {
  description = "CVM private ip addresses"
  value = [for instance in tencentcloud_instance.k8s_server : instance.private_ip]
}

output "cfs_pgroup_id" {
  value = try(module.k8s_cfs[0].cfs_access_group_id, null)
}
