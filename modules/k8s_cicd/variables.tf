variable "vpc_id" {
  type = string
  description = "VPC id on tencent cloud"
}

variable "subnet_id" {
  type = string
  description = "subnet id on tencent cloud"
}

variable "ssh_key_private_key_path" {
  type = string
  description = "SSH private key path"
}

variable "ssh_key_public_key_path" {
  type = string
  description = "SSH public key path"
}

variable "k8s_kubeconfig_path" {
  type = string
  description = "Path to the kubeconfig file"
}

variable "k8s_master_public_ip" {
  type = string
  description = "K8s master public ip"
}

variable "cvm_login_user" {
  type = string
  description = "CVM login user"
}

variable "cfs_pgroup_id" {
  type = string
  description = "CFS access group ID"
}

variable "ingress_nginx_version" {
  type = string
  description = "Helm Ingress Nginx version"
}

variable "harbor_version" {
  type = string
  description = "Helm Harbor version"
}

variable "harbor_url" {
  type = string
  description = "Helm Harbor URL"
}

variable "harbor_password" {
  type = string
  description = "Harbor admin password"
}
