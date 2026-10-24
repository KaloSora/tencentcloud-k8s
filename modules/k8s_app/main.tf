locals {
  environment_names = toset([
    "dev",
    "uat",
    "preprod",
    "prod",
  ])
  k8s_pss_version = "v${join(".", slice(split(".", trimprefix(var.k8s_version, "v")), 0, 2))}"
}

resource "kubernetes_namespace" "environment" {
  for_each = local.environment_names

  metadata {
    name = each.value

    labels = {
      "app.kubernetes.io/managed-by"               = "terraform"
      "environment"                                = each.value
      "pod-security.kubernetes.io/enforce"         = "restricted"
      "pod-security.kubernetes.io/enforce-version" = local.k8s_pss_version
      "pod-security.kubernetes.io/audit"           = "restricted"
      "pod-security.kubernetes.io/audit-version"   = local.k8s_pss_version
      "pod-security.kubernetes.io/warn"            = "restricted"
      "pod-security.kubernetes.io/warn-version"    = local.k8s_pss_version
    }
  }
}
