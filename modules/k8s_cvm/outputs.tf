output "master_public_ip" {
  description = "Public IP of the master node"
  value       = try(tencentcloud_instance.k8s_server["master1"].public_ip, null)
}

output "instance_id" {
  description = "CVM instance ID of the first master node"
  value       = local.first_master_instance != null ? local.first_master_instance.id : null
}

output "private_ips" {
  description = "CVM private ip addresses"
  value       = [for instance in tencentcloud_instance.k8s_server : instance.private_ip]
}

output "registry_nodes" {
  description = "Node identities and SSH endpoints for post-cluster registry configuration"
  value = {
    for key, instance in tencentcloud_instance.k8s_server : key => {
      instance_id = instance.id
      host        = instance.public_ip
    }
  }
}
