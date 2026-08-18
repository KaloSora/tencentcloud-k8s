variable "ssh_key_private_key_path" {
  type = string
  description = "SSH private key path"
}

variable "ssh_key_public_key_path" {
  type = string
  description = "SSH public key path"
}

variable "k8s_master_public_ip" {
  type = string
  description = "K8s master public ip"
}

variable "cvm_login_user" {
  type = string
  description = "CVM login user"
}