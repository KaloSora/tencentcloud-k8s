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

variable "jenkins_pipeline_repository_url" {
  type        = string
  description = "Public Git repository containing the Jenkins pipeline"

  validation {
    condition     = can(regex("^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\\.git)?$", var.jenkins_pipeline_repository_url))
    error_message = "jenkins_pipeline_repository_url must be a GitHub HTTPS repository URL."
  }
}

variable "jenkins_pipeline_repository_branch" {
  type        = string
  description = "Git branch containing the Jenkinsfile"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.jenkins_pipeline_repository_branch))
    error_message = "jenkins_pipeline_repository_branch contains unsupported characters."
  }
}

variable "jenkins_pipeline_script_path" {
  type        = string
  description = "Path to the Jenkinsfile within the pipeline repository"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.jenkins_pipeline_script_path))
    error_message = "jenkins_pipeline_script_path must be a repository-relative path."
  }
}

variable "plane_version" {
  type        = string
  description = "Plane Community Edition Helm chart version"
}

variable "plane_enabled" {
  type        = bool
  description = "Whether to deploy Plane Community Edition"
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
