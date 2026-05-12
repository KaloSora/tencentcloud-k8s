variable "secret_id" {
  type = string
  description = "tencent cloud access id"
  default = "Your Access ID"
}

variable "secret_key" {
  type = string
  description = "tencent cloud access key"
  default = "Your Access Key"
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

variable "cvm_availability_zone" {
  type = string
  description = "tencent cvm availability zone"
  default = "ap-hongkong-2"
}

variable "cvm_cpu_core_count" {
  type = number
  description = "The CPU core count of the instance."
  default = 4
}

variable "cvm_memory_size" {
  type = number
  description = "The memory size(GB) of the instance."
  default = 8
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