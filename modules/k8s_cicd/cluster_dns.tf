# kubeadm owns the ConfigMap itself. Manage only its Corefile data field, keeping
# the existing resolver configuration and replacing our marked block on refresh.
data "kubernetes_config_map_v1" "cluster_dns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
}

locals {
  harbor_dns_enabled = contains(local.enabled_component_names, "harbor")
  harbor_dns_host    = try(nonsensitive(var.components["harbor"].config["harbor_url"]), "harbor.core.com")
  cluster_dns_base = replace(
    # A previous targeted destroy may already have removed this managed field.
    # Keep destroy planning safe; the precondition below still rejects an
    # empty Corefile when creating/updating the DNS configuration.
    lookup(data.kubernetes_config_map_v1.cluster_dns.data, "Corefile", ""),
    "/(?m)^    # BEGIN terraform cicd ingress DNS\n(?s:.*?)^    # END terraform cicd ingress DNS\n/",
    ""
  )
  harbor_dns_rule = local.harbor_dns_enabled ? join("\n", [
    "    # BEGIN terraform cicd ingress DNS",
    "    rewrite name exact ${local.harbor_dns_host} ${var.ingress_controller_service_fqdn}",
    "    # END terraform cicd ingress DNS",
    ""
  ]) : ""
  cluster_dns_corefile = replace(local.cluster_dns_base, ".:53 {\n", ".:53 {\n${local.harbor_dns_rule}")
}

resource "kubernetes_config_map_v1_data" "cluster_dns" {
  metadata {
    name      = data.kubernetes_config_map_v1.cluster_dns.metadata[0].name
    namespace = data.kubernetes_config_map_v1.cluster_dns.metadata[0].namespace
  }
  field_manager = "terraform-cicd-dns"
  force         = true
  data          = { Corefile = local.cluster_dns_corefile }

  lifecycle {
    precondition {
      condition     = strcontains(local.cluster_dns_base, ".:53 {\n")
      error_message = "Expected kubeadm's default .:53 CoreDNS server block; review a custom Corefile before applying."
    }
    precondition {
      condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", local.harbor_dns_host))
      error_message = "Harbor URL must be a DNS hostname without scheme, port, path or whitespace."
    }
  }
}
