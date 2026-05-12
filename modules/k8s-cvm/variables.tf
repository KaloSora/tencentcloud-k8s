# variable "password" {
#   type = string
#   description = "The password of the instance."
# }

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