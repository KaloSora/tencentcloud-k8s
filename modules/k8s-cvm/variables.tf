# variable "password" {
#   type = string
#   description = "The password of the instance."
# }

variable "ssh_key_private_key_path" {
  type = string
  description = "SSH private key path"
}

variable "ssh_key_public_key_path" {
  type = string
  description = "SSH public key path"
}

variable "cvm_availability_zone" {
  type = string
  description = "The availability zone of the instance."
}

variable "cvm_charge_type" {
  type = string
  description = "The charge type of the instance."
  default = "SPOTPAID"
}

variable "cvm_os_regex" {
  type = string
  description = "cvm os regex to filter public image"
}

variable "cvm_login_user" {
  type = string
  description = "cvm login user"
}

variable "k8s_cluster" {
  description = "K8s cluster object"
}

variable "cvm_cfs_enabled" {
  type = bool
  description = "K8s cfs enabled flag"
  default = false
}

variable "vpc_id" {
  type = string
  description = "VPC id on tencent cloud"
}

variable "subnet_id" {
  type = string
  description = "subnet id on tencent cloud"
}

variable "cfs_cidr" {
  description = "CFS CIDR block"
  type        = string
}

# variable "cvm_cfs_ip" {
#   type = string
#   description = "K8s cfs mount ip"
#   default = ""
# }

# variable "cvm_cfs_mount_point" {
#   type = string
#   description = "K8s cfs mount point"
#   default = ""
# }

variable "cvm_cfs_secret_id" {
  type = string
  description = "tencent cloud cfs access id"
  default = ""
}

variable "cvm_cfs_secret_key" {
  type = string
  description = "tencent cloud cfs access key"
  default = ""
}

variable "cvm_cfs_csi_secret" {
  type = string
  description = "K8s cfs csi secret"
}

variable "k8s_version" {
  type = string
  description = "K8s version"
}

variable "k8s_cidr" {
  type = string
  description = "K8s CIDR"
}

variable "k8s_cri_dockerd_version" {
  type = string
  description = "K8s CRI Dockerd version"
}

variable "k8s_cfssl_version" {
  type = string
  description = "K8s CFSSL version"
}

variable "k8s_helm_version" {
  type = string
  description = "K8s HELM version"
}

variable "k8s_helm_enabled" {
  type = bool
  description = "Helm plugin installation flag"
  default = false
}

variable "k8s_cfssl_enabled" {
  type = bool
  description = "CFSSL plugin installation flag"
  default = false
}