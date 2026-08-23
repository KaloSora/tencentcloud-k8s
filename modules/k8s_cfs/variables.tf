variable "availability_zone" {
    description = "The availability zone for the CFS instance."
    type        = string
}

variable "vpc_id" {
  type = string
  description = "VPC id on tencent cloud"
}

variable "subnet_id" {
  type = string
  description = "subnet id on tencent cloud"
}

variable "cfs_enabled" {
  type = bool
  description = "Whether to enable CFS for the K8s cluster"
  default = false
}

variable "cfs_cidr" {
  description = "CFS CIDR block"
  type        = string
}