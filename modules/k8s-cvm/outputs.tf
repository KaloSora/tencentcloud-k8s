output "public_ip" {
  description = "vm public ip address"
  value       = tencentcloud_instance.k3s_server[0].public_ip
}

output "instance_id" {
  description = "vm instance id"
  value       = tencentcloud_instance.k3s_server[0].id
}

# output "password" {
#   description = "vm password"
#   value       = var.password
# }
