variable "harbor_version" {
  type        = string
  description = "Helm Harbor version"
}

variable "harbor_url" {
  type        = string
  description = "Helm Harbor URL"
}

variable "harbor_password" {
  type        = string
  description = "Harbor admin password"
}

variable "argocd_version" {
  type        = string
  description = "Argo CD Helm chart version"
}

variable "argocd_url" {
  type        = string
  description = "External hostname for Argo CD"
}

variable "argocd_admin_password" {
  type        = string
  description = "Initial password for the Argo CD admin user"
  sensitive   = true
}

variable "jenkins_version" {
  type        = string
  description = "Jenkins Helm chart version"
}

variable "jenkins_url" {
  type        = string
  description = "External HTTP hostname for Jenkins"
}

variable "jenkins_admin_username" {
  type        = string
  description = "Jenkins administrator username"
}

variable "jenkins_admin_password" {
  type        = string
  description = "Jenkins administrator password"
  sensitive   = true
}

variable "plane_version" {
  type        = string
  description = "Plane Community Edition Helm chart version"
}

variable "plane_url" {
  type        = string
  description = "External HTTP hostname for Plane"
}

variable "plane_admin_email" {
  type        = string
  description = "Email address for the initial Plane instance administrator"
}

variable "plane_admin_password" {
  type        = string
  description = "Password for the initial Plane instance administrator"
  sensitive   = true
}

variable "storage_class_name" {
  description = "Storage class name for persistent volumes"
  type        = string
}

variable "k8s_version" {
  type        = string
  description = "Kubernetes version"
}
