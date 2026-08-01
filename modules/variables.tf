variable "secret_id" {
  type = string
  description = "tencent cloud access id"
  default = ""
}

variable "secret_key" {
  type = string
  description = "tencent cloud access key"
  default = ""
}

# variable "password" {
#   type = string
#   description = "tencent cloud instance password"
# }

variable "region" {
  type = string
  description = "tencent cloud region"
  default = "ap-hongkong"
}

variable "vpc_id" {
  type = string
  description = "VPC id on tencent cloud"
}

variable "subnet_id" {
  type = string
  description = "subnet id on tencent cloud"
}

variable "cvm_availability_zone" {
  type = string
  description = "tencent cvm availability zone"
  default = "ap-hongkong-2"
}

variable "cvm_charge_type" {
  type = string
  description = "The charge type of the instance. Valid values: POSTPAID_BY_HOUR, SPOTPAID."
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

### Cloud File Storage config
variable "cfs_enabled" {
  type = bool
  description = "Whether to enable cfs"
}

variable "cfs_allow_cidr" {
  type = string
  description = "CFS allowed CIDR block"
}

variable "cfs_mount_point" {
  type = string
  description = "CFS mount point"
}

variable "cfs_csi_secret" {
  type = string
  description = "CFS CSI secret"
}