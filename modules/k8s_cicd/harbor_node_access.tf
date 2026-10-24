data "kubernetes_service_v1" "harbor_ingress" {
  count = local.harbor_dns_enabled ? 1 : 0
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
}

locals {
  harbor_node_script = file("${path.module}/templates/harbor_node_access.py")
}

# This post-cluster step cannot run during CVM initialization: the Ingress
# ClusterIP does not exist yet. Never modify CVM bootstrap triggers for it.
resource "terraform_data" "harbor_node_access" {
  for_each = local.harbor_dns_enabled ? var.registry_nodes : {}

  # The payload probes /v2/: the Harbor Ingress must exist on fresh clusters.
  depends_on = [module.component["harbor"]]

  triggers_replace = {
    instance_id       = each.value.instance_id
    host              = each.value.host
    registry          = local.harbor_dns_host
    ingress_ip        = data.kubernetes_service_v1.harbor_ingress[0].spec[0].cluster_ip
    script_hash       = sha256(local.harbor_node_script)
    executor_revision = "1"
  }

  connection {
    type        = "ssh"
    host        = each.value.host
    user        = var.registry_ssh_user
    private_key = file(var.registry_ssh_key_path)
    timeout     = "2m"
  }

  provisioner "file" {
    content     = local.harbor_node_script
    destination = "/tmp/terraform-harbor-node.py"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "python3 /tmp/terraform-harbor-node.py --registry '${local.harbor_dns_host}' --address '${data.kubernetes_service_v1.harbor_ingress[0].spec[0].cluster_ip}' --apply",
      "rm -f /tmp/terraform-harbor-node.py",
    ]
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9]+([.-][a-z0-9]+)*$", local.harbor_dns_host))
      error_message = "Harbor node registry must be a DNS hostname without scheme, port or path."
    }
    precondition {
      condition     = can(regex("^[a-fA-F0-9:.]+$", data.kubernetes_service_v1.harbor_ingress[0].spec[0].cluster_ip))
      error_message = "The Ingress Controller must have an IP-valued ClusterIP."
    }
    precondition {
      condition     = var.registry_ssh_key_path != ""
      error_message = "Node registry configuration requires the existing SSH private key path."
    }
  }
}
