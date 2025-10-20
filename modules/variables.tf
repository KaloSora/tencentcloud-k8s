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

variable "region" {
  type = string
  description = "tencent cloud region"
  default = "ap-hongkong"
}

variable "password" {
  type = string
  description = "tencent cloud instance password"
}

variable "k8s_map" {
  description = "K8s map list"
}
