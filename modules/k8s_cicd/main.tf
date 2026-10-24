locals {
  enabled_component_names = nonsensitive(toset([
    for name, component in var.components : name
    if component.enabled
  ]))
  jenkins_enabled                         = contains(local.enabled_component_names, "jenkins")
  plane_enabled                           = contains(local.enabled_component_names, "plane")
  jenkins_agent_namespace                 = "cicd-build"
  jenkins_agent_service_account_name      = "jenkins-agent"
  jenkins_controller_service_account_name = "jenkins-controller"
  k8s_pss_version                         = "v${join(".", slice(split(".", var.k8s_version), 0, 2))}"

  component_template_vars = {
    for name, component in var.components : name => merge(
      component.config,
      {
        storage_class = var.storage_class_name
      },
      name == "argocd" ? {
        argocd_admin_password_bcrypt = bcrypt(component.config["argocd_admin_password"])
      } : {},
      name == "jenkins" ? {
        jenkins_agent_namespace                 = local.jenkins_agent_namespace
        jenkins_agent_service_account_name      = local.jenkins_agent_service_account_name
        jenkins_controller_service_account_name = local.jenkins_controller_service_account_name
      } : {},
      name == "plane" && local.plane_enabled ? {
        plane_secret_key             = random_password.plane_secret_key[0].result
        plane_live_server_secret_key = random_password.plane_live_server_secret_key[0].result
        postgres_password            = random_password.plane_postgres_password[0].result
        rabbitmq_password            = random_password.plane_rabbitmq_password[0].result
        minio_password               = random_password.plane_minio_password[0].result
      } : {}
    )
  }

  rendered_component_values = {
    for name, component in var.components : name => [
      for template_name in component.value_templates :
      templatefile(
        "${path.module}/helm_values/${template_name}",
        local.component_template_vars[name]
      )
    ] if contains(local.enabled_component_names, name)
  }
}

# One namespace is created for every enabled component in the inventory.
resource "kubernetes_namespace" "component" {
  for_each = local.enabled_component_names

  metadata {
    name = nonsensitive(var.components[each.key].namespace)

    labels = {
      "pod-security.kubernetes.io/audit"         = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version
      "pod-security.kubernetes.io/warn"          = "restricted"
      "pod-security.kubernetes.io/warn-version"  = local.k8s_pss_version
    }
  }
}

# Jenkins-specific runtime resources stay outside the generic Helm component
# module because they must exist before the Jenkins release is installed.
resource "kubernetes_namespace" "jenkins_agent_namespace" {
  count = local.jenkins_enabled ? 1 : 0

  metadata {
    name = local.jenkins_agent_namespace

    labels = {
      "pod-security.kubernetes.io/audit"         = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version
      "pod-security.kubernetes.io/warn"          = "restricted"
      "pod-security.kubernetes.io/warn-version"  = local.k8s_pss_version
    }
  }
}

# The controller's config-reload sidecar watches JCasC ConfigMaps in the
# Jenkins namespace. Keep this permission separate from agent scheduling so
# the controller does not receive broader access to the Jenkins namespace.
resource "kubernetes_role" "jenkins_watch_casc_configmaps" {
  count = local.jenkins_enabled ? 1 : 0

  metadata {
    name      = "jenkins-watch-casc-configmaps"
    namespace = kubernetes_namespace.component["jenkins"].metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins_controller_watch_casc_configmaps" {
  count = local.jenkins_enabled ? 1 : 0

  metadata {
    name      = "jenkins-controller-watch-casc-configmaps"
    namespace = kubernetes_namespace.component["jenkins"].metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_watch_casc_configmaps[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.jenkins_controller_service_account_name
    namespace = kubernetes_namespace.component["jenkins"].metadata[0].name
  }
}

resource "kubernetes_service_account" "jenkins_agent" {
  count = local.jenkins_enabled ? 1 : 0

  metadata {
    name      = local.jenkins_agent_service_account_name
    namespace = kubernetes_namespace.jenkins_agent_namespace[0].metadata[0].name
  }

  automount_service_account_token = false
}

# The controller can only manage ephemeral build pods in the dedicated agent
# namespace. Build agents themselves receive no Kubernetes API permissions.
resource "kubernetes_role" "jenkins_schedule_agents" {
  count = local.jenkins_enabled ? 1 : 0

  metadata {
    name      = "jenkins-schedule-agents"
    namespace = kubernetes_namespace.jenkins_agent_namespace[0].metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create", "delete", "get", "list", "patch", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create", "get"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins_controller_schedule_agents" {
  count = local.jenkins_enabled ? 1 : 0

  metadata {
    name      = "jenkins-controller-schedule-agents"
    namespace = kubernetes_namespace.jenkins_agent_namespace[0].metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_schedule_agents[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.jenkins_controller_service_account_name
    namespace = kubernetes_namespace.component["jenkins"].metadata[0].name
  }
}

# Plane keeps generated secrets in Terraform state and only creates them while
# the component is enabled.
resource "random_password" "plane_secret_key" {
  count   = local.plane_enabled ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "plane_live_server_secret_key" {
  count   = local.plane_enabled ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "plane_postgres_password" {
  count   = local.plane_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "plane_rabbitmq_password" {
  count   = local.plane_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "plane_minio_password" {
  count   = local.plane_enabled ? 1 : 0
  length  = 32
  special = false
}

# Every enabled inventory item is installed by the same reusable Helm module.
module "component" {
  for_each = local.enabled_component_names
  source   = "./helm_component"

  component = {
    release_name  = nonsensitive(var.components[each.key].release_name)
    repository    = nonsensitive(var.components[each.key].repository)
    chart         = nonsensitive(var.components[each.key].chart)
    version       = nonsensitive(var.components[each.key].version)
    namespace     = nonsensitive(var.components[each.key].namespace)
    timeout       = nonsensitive(var.components[each.key].timeout)
    atomic        = nonsensitive(var.components[each.key].atomic)
    wait          = nonsensitive(var.components[each.key].wait)
    wait_for_jobs = nonsensitive(var.components[each.key].wait_for_jobs)
  }
  values = concat(
    local.rendered_component_values[each.key],
    each.key == "jenkins" ? local.jenkins_gitops_values : []
  )

  depends_on = [
    kubernetes_config_map_v1_data.cluster_dns,
    kubernetes_namespace.component,
    kubernetes_role_binding.jenkins_controller_watch_casc_configmaps,
    kubernetes_role_binding.jenkins_controller_schedule_agents,
    kubernetes_service_account.jenkins_agent,
  ]
}
