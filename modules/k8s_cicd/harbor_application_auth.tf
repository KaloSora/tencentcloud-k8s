locals {
  app_pull_enabled = local.harbor_dns_enabled && length(var.application_namespaces) > 0
  app_pull_script  = file("${path.module}/script/application_pull_auth.py")
  app_pull_hash = substr(sha256(jsonencode([
    local.app_pull_script, local.harbor_auth_script, sort(tolist(var.application_namespaces)),
    local.harbor_auth_registry, local.harbor_auth_project, var.application_robot_duration_days,
    var.application_pull_bootstrap_revision,
  ])), 0, 12)
}

# The chart owns RBAC and a daily rotation CronJob. The native Job below
# explicitly waits for completion, independently of Helm's readiness result.
# Robot passwords travel only inside the cluster, never via Terraform state.
resource "helm_release" "application_pull_credentials" {
  count = local.app_pull_enabled ? 1 : 0

  name             = "harbor-app-pull"
  namespace        = kubernetes_namespace.component["harbor"].metadata[0].name
  chart            = "${path.module}/charts/harbor-app-pull"
  create_namespace = false
  atomic           = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 900

  values = [yamlencode({
    namespaces      = sort(tolist(var.application_namespaces))
    registry        = local.harbor_auth_registry
    harborURL       = "http://${local.harbor_auth_release}-core.${local.harbor_auth_namespace}.svc.cluster.local"
    adminSecret     = "${local.harbor_auth_release}-core"
    project         = local.harbor_auth_project
    durationDays    = var.application_robot_duration_days
    bootstrapHash   = local.app_pull_hash
    bootstrapScript = local.app_pull_script
    registryLibrary = local.harbor_auth_script
  })]

  depends_on = [module.component["harbor"], terraform_data.harbor_node_access]
}

resource "kubernetes_job_v1" "application_pull_credentials" {
  count = local.app_pull_enabled ? 1 : 0
  metadata {
    name      = "harbor-app-pull-verify-${local.app_pull_hash}"
    namespace = kubernetes_namespace.component["harbor"].metadata[0].name
    labels    = { "app.kubernetes.io/name" = "harbor-app-pull" }
  }
  spec {
    backoff_limit           = 2
    active_deadline_seconds = 600
    template {
      metadata {
        labels = { "app.kubernetes.io/name" = "harbor-app-pull" }
      }
      spec {
        service_account_name            = helm_release.application_pull_credentials[0].name
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
          command = ["python3", "-B", "/bootstrap/application_pull_auth.py"]
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities { drop = ["ALL"] }
          }
          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "500m", memory = "128Mi" }
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
            value = tostring(var.application_robot_duration_days)
          }
          env {
            name  = "APPLICATION_NAMESPACES"
            value = jsonencode(sort(tolist(var.application_namespaces)))
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
            name = helm_release.application_pull_credentials[0].name
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
}
