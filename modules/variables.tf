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

variable "ssh_key_private_key_path" {
  type = string
  description = "SSH private key path"
}

variable "ssh_key_public_key_path" {
  type = string
  description = "SSH public key path"
}

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

variable "k8s_cost_saving_mode" {
  type = bool
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

# variable "cfs_mount_point" {
#   type = string
#   description = "CFS mount point"
# }

variable "cfs_csi_secret" {
  type = string
  description = "CFS CSI secret"
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

variable "helm_ingress_nginx_version" {
  type = string
  description = "Ingress Nginx version"
}

variable "helm_harbor_version" {
  type = string
  description = "Harbor version"
}

variable "helm_harbor_url" {
  type = string
  description = "Harbor URL"
}

variable "helm_harbor_password" {
  type = string
  description = "Harbor admin password"
  default = "Harbor12345"
}

variable "k8s_kubeconfig_path" {
  type = string
  description = "Path to the kubeconfig file"
}

variable "helm_loki_version" {
  type = string
  description = "Loki version"
}

variable "helm_grafana_version" {
  type = string
  description = "Grafana version"
}

variable "helm_grafana_url" {
  type = string
  description = "Grafana URL"
}

variable "helm_grafana_password" {
  type = string
  description = "Grafana admin password"
}

variable "helm_kube_prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
}