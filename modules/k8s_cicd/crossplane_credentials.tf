locals {
  crossplane_enabled = contains(local.enabled_component_names, "crossplane")
  crossplane_tencentcloud_credentials = jsonencode({
    secret_id  = var.secret_id
    secret_key = var.secret_key
    region     = var.crossplane_region
  })
}

# Kubernetes provider encodes data values; do not base64encode this JSON.
# Sensitive inputs hide CLI values, but the Secret is still stored in state.
# Argo CD owns only the ProviderConfig reference, never this Secret.
resource "kubernetes_secret_v1" "crossplane_tencentcloud" {
  count = local.crossplane_enabled ? 1 : 0

  metadata {
    name      = "tencentcloud-credentials"
    namespace = kubernetes_namespace.component["crossplane"].metadata[0].name
  }

  type = "Opaque"
  data = {
    credentials = local.crossplane_tencentcloud_credentials
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[^[:space:]]+$", var.secret_id)) && can(regex("^[^[:space:]]+$", var.secret_key))
      error_message = "Crossplane requires nonempty secret_id and secret_key without whitespace. Supply them through private Terraform inputs."
    }
  }
}
