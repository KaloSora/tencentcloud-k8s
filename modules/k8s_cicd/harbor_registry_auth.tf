locals {
  harbor_auth_enabled   = local.jenkins_enabled && contains(local.enabled_component_names, "harbor")
  harbor_auth_script    = file("${path.module}/script/harbor_registry_auth.py")
  harbor_auth_project   = nonsensitive(try(var.components["jenkins"].config["jenkins_harbor_project"], "library"))
  harbor_auth_duration  = nonsensitive(try(var.components["jenkins"].config["jenkins_harbor_robot_duration_days"], "90"))
  harbor_auth_revision  = nonsensitive(try(var.components["jenkins"].config["jenkins_harbor_bootstrap_revision"], "1"))
  harbor_auth_registry  = nonsensitive(try(var.components["harbor"].config["harbor_url"], "harbor.core.com"))
  harbor_auth_release   = nonsensitive(try(var.components["harbor"].release_name, "harbor"))
  harbor_auth_namespace = nonsensitive(try(var.components["harbor"].namespace, "harbor"))
  harbor_auth_hash = substr(sha256(jsonencode([
    local.harbor_auth_script, local.harbor_auth_project, local.harbor_auth_duration,
    local.harbor_auth_revision, local.harbor_auth_registry, local.harbor_auth_release
  ])), 0, 12)
}

# The password is created by Harbor and transferred to Kubernetes only inside
# this Job. Neither Terraform state nor the workstation receives the password.
resource "kubernetes_service_account_v1" "harbor_auth_bootstrap" {
  count = local.harbor_auth_enabled ? 1 : 0
  metadata {
    name      = "jenkins-harbor-bootstrap"
    namespace = kubernetes_namespace.component["harbor"].metadata[0].name
  }
  automount_service_account_token = true
}

resource "kubernetes_role_v1" "harbor_auth_bootstrap" {
  count = local.harbor_auth_enabled ? 1 : 0
  metadata {
    name      = "jenkins-harbor-bootstrap"
    namespace = kubernetes_namespace.jenkins_agent_namespace[0].metadata[0].name
  }
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["harbor-docker-config"]
    verbs          = ["get", "update"]
  }
  # Kubernetes RBAC cannot restrict create by resourceNames. This permission
  # applies only in the build namespace; no list/delete or cluster-wide grant.
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create"]
  }
}

resource "kubernetes_role_binding_v1" "harbor_auth_bootstrap" {
  count = local.harbor_auth_enabled ? 1 : 0
  metadata {
    name      = "jenkins-harbor-bootstrap"
    namespace = kubernetes_namespace.jenkins_agent_namespace[0].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.harbor_auth_bootstrap[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.harbor_auth_bootstrap[0].metadata[0].name
    namespace = kubernetes_service_account_v1.harbor_auth_bootstrap[0].metadata[0].namespace
  }
}

resource "kubernetes_config_map_v1" "harbor_auth_bootstrap" {
  count = local.harbor_auth_enabled ? 1 : 0
  metadata {
    name      = "jenkins-harbor-bootstrap"
    namespace = kubernetes_namespace.component["harbor"].metadata[0].name
  }
  data = { "bootstrap.py" = local.harbor_auth_script }
}

resource "kubernetes_job_v1" "harbor_auth_bootstrap" {
  count = local.harbor_auth_enabled ? 1 : 0
  metadata {
    name      = "jenkins-harbor-auth-${local.harbor_auth_hash}"
    namespace = kubernetes_namespace.component["harbor"].metadata[0].name
  }
  spec {
    backoff_limit           = 2
    active_deadline_seconds = 600
    template {
      metadata {
        labels = { "app.kubernetes.io/name" = "jenkins-harbor-bootstrap" }
      }
      spec {
        service_account_name            = kubernetes_service_account_v1.harbor_auth_bootstrap[0].metadata[0].name
        automount_service_account_token = true
        restart_policy                  = "Never"
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          seccomp_profile { type = "RuntimeDefault" }
        }
        container {
          name    = "bootstrap"
          image   = "python:3.13-slim"
          command = ["python3", "-B", "/bootstrap/bootstrap.py"]
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities { drop = ["ALL"] }
          }
          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "500m", memory = "256Mi" }
          }
          env {
            name  = "HARBOR_URL"
            value = "http://${local.harbor_auth_release}-core.${local.harbor_auth_namespace}.svc.cluster.local"
          }
          env {
            name  = "REGISTRY_HOST"
            value = local.harbor_auth_registry
          }
          env {
            name  = "HARBOR_PROJECT"
            value = local.harbor_auth_project
          }
          env {
            name  = "ROBOT_DURATION_DAYS"
            value = local.harbor_auth_duration
          }
          env {
            name = "HARBOR_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = "${local.harbor_auth_release}-core"
                key  = "HARBOR_ADMIN_PASSWORD"
              }
            }
          }
          volume_mount {
            name       = "script"
            mount_path = "/bootstrap"
            read_only  = true
          }
        }
        volume {
          name = "script"
          config_map {
            name = kubernetes_config_map_v1.harbor_auth_bootstrap[0].metadata[0].name
          }
        }
      }
    }
  }
  wait_for_completion = true
  timeouts {
    create = "12m"
    update = "12m"
  }
  # Keep the completed Job (no TTL), so ordinary applies do not rotate secrets.
  # On destroy, delete the Job before removing Harbor and its database/PVCs.
  depends_on = [module.component["harbor"], kubernetes_role_binding_v1.harbor_auth_bootstrap]
}
