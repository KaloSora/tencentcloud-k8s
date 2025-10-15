output "public_ip" {
  description = "vm public ip address"
  value       = tencentcloud_instance.web[0].public_ip
}

output "instance_id" {
  description = "vm instance id"
  value       = tencentcloud_instance.web[0].id
}

output "password" {
  description = "vm password"
  value       = var.password
}
