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

variable "storage_class_name" {
  description = "Storage class name for persistent volumes"
  type        = string
}