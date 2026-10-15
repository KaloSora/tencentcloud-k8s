variable "component" {
  description = "Non-sensitive Helm release metadata for one CI/CD component"

  type = object({
    release_name  = string
    repository    = string
    chart         = string
    version       = string
    namespace     = string
    timeout       = number
    atomic        = bool
    wait          = bool
    wait_for_jobs = bool
  })
}

variable "values" {
  type        = list(string)
  description = "Rendered Helm values documents"
  sensitive   = true
}
