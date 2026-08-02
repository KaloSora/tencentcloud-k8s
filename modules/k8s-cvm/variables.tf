# variable "password" {
#   type = string
#   description = "The password of the instance."
# }

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