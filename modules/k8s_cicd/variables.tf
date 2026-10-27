variable "components" {
  description = "CI/CD component inventory rendered through the generic Helm component module"
  sensitive   = true

  type = map(object({
    enabled         = bool
    release_name    = string
    namespace       = string
    repository      = string
    chart           = string
    version         = string
    timeout         = number
    atomic          = bool
    wait            = bool
    wait_for_jobs   = bool
    value_templates = list(string)
    config          = map(string)
  }))

  validation {
    condition = alltrue([
      for name in keys(var.components) :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name))
    ])
    error_message = "Component keys must be valid lowercase Kubernetes-style names."
  }

  validation {
    condition = alltrue(flatten([
      for component in values(var.components) : [
        for template_name in component.value_templates :
        can(regex("^[A-Za-z0-9_.-]+\\.ya?ml$", template_name))
      ]
    ]))
    error_message = "value_templates entries must be YAML filenames located in helm_values."
  }

  validation {
    condition = length(distinct([
      for component in values(var.components) : component.namespace
      if component.enabled
      ])) == length([
      for component in values(var.components) : component.namespace
      if component.enabled
    ])
    error_message = "Enabled CI/CD components must use unique namespaces."
  }
}

variable "gitops_credentials_id" {
  description = "Jenkins Secret text credential ID used by the GitOps promotion pipeline"
  type        = string
  default     = "gitops-github-token"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", var.gitops_credentials_id))
    error_message = "gitops_credentials_id must contain only letters, numbers, dots, underscores and hyphens, starting with a letter or number."
  }
}

variable "gitops_github_token" {
  description = "Required nonempty GitHub token for Jenkins promotion. Stored in Terraform state."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = can(regex("^[^[:space:]]+$", var.gitops_github_token))
    error_message = "gitops_github_token must not be empty or contain whitespace."
  }
}

variable "argocd_infra_gitops_repo_url" {
  description = "Infrastructure GitOps repository read by the dedicated Argo CD bootstrap; empty disables it"
  type        = string
  default     = ""
}

variable "argocd_gitops_repo_url" {
  description = "GitOps repository read by the Argo CD bootstrap Application; empty disables bootstrap"
  type        = string
  default     = ""
}

variable "storage_class_name" {
  description = "Storage class name for persistent volumes"
  type        = string
}

variable "k8s_version" {
  type        = string
  description = "Kubernetes version"
}

variable "ingress_controller_service_fqdn" {
  description = "Internal Ingress Controller Service DNS name used for Harbor DNS rewrites"
  type        = string
  default     = "ingress-nginx-controller.ingress-nginx.svc.cluster.local"
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.ingress_controller_service_fqdn))
    error_message = "Ingress Controller Service must be a DNS hostname."
  }
}

variable "registry_nodes" {
  description = "Docker nodes configured after Ingress exists; instance identity triggers reprovisioning"
  type        = map(object({ instance_id = string, host = string }))
  default     = {}
}

variable "registry_ssh_user" {
  type        = string
  default     = "root"
  description = "Existing privileged SSH account used to configure the node's Docker daemon"
}

variable "registry_ssh_key_path" {
  type        = string
  default     = ""
  description = "Existing local SSH private key path; key material is not stored in registry resource input"
}

variable "application_namespaces" {
  type        = set(string)
  default     = []
  description = "Existing application namespaces receiving pull-only Harbor robots and Secrets"
  validation {
    condition = alltrue([
      for name in var.application_namespaces : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name))
    ])
    error_message = "Application namespace names must be valid Kubernetes namespace names."
  }
}

variable "application_robot_duration_days" {
  type        = number
  default     = 90
  description = "Lifetime of application pull-only robots; a daily CronJob renews within seven days of expiry"
  validation {
    condition     = var.application_robot_duration_days >= 14 && floor(var.application_robot_duration_days) == var.application_robot_duration_days
    error_message = "Application robot duration must be an integer of at least 14 days."
  }
}

variable "application_pull_bootstrap_revision" {
  type        = string
  default     = "1"
  description = "Bump to force the initial pull credential verification Job to run again"
}
