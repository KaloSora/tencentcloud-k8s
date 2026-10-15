locals {
  helm_default_timeout                    = 600
  harbor_namespace                        = "harbor"
  jenkins_agent_namespace                 = "cicd-build"
  jenkins_agent_service_account_name      = "jenkins-agent"
  jenkins_controller_service_account_name = "jenkins-controller"
  k8s_pss_version                         = "v${join(".", slice(split(".", var.k8s_version), 0, 2))}"
}

### PSA configuration for monitoring
resource "kubernetes_namespace" "harbor_namespace" {
  metadata {
    name = local.harbor_namespace

    labels = {
      "pod-security.kubernetes.io/audit"         = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version

      "pod-security.kubernetes.io/warn"         = "restricted"
      "pod-security.kubernetes.io/warn-version" = local.k8s_pss_version
    }
  }
}

resource "kubernetes_namespace" "argocd_namespace" {
  metadata {
    name = "argocd"
    labels = {
      "pod-security.kubernetes.io/audit"         = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version
      "pod-security.kubernetes.io/warn"          = "restricted"
      "pod-security.kubernetes.io/warn-version"  = local.k8s_pss_version
    }
  }
}

resource "kubernetes_namespace" "jenkins_namespace" {
  metadata {
    name = "jenkins"
    labels = {
      "pod-security.kubernetes.io/audit"         = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version
      "pod-security.kubernetes.io/warn"          = "restricted"
      "pod-security.kubernetes.io/warn-version"  = local.k8s_pss_version
    }
  }
}

resource "kubernetes_namespace" "jenkins_agent_namespace" {
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

resource "kubernetes_service_account" "jenkins_agent" {
  metadata {
    name      = local.jenkins_agent_service_account_name
    namespace = kubernetes_namespace.jenkins_agent_namespace.metadata[0].name
  }

  automount_service_account_token = false
}

# The controller can only manage ephemeral build pods in the dedicated agent
# namespace. Build agents themselves receive no Kubernetes API permissions.
resource "kubernetes_role" "jenkins_schedule_agents" {
  metadata {
    name      = "jenkins-schedule-agents"
    namespace = kubernetes_namespace.jenkins_agent_namespace.metadata[0].name
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
  metadata {
    name      = "jenkins-controller-schedule-agents"
    namespace = kubernetes_namespace.jenkins_agent_namespace.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_schedule_agents.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.jenkins_controller_service_account_name
    namespace = kubernetes_namespace.jenkins_namespace.metadata[0].name
  }
}

resource "kubernetes_namespace" "plane_namespace" {
  count = var.plane_enabled ? 1 : 0

  metadata {
    name = "plane"
    labels = {
      "pod-security.kubernetes.io/audit"         = "restricted"
      "pod-security.kubernetes.io/audit-version" = local.k8s_pss_version
      "pod-security.kubernetes.io/warn"          = "restricted"
      "pod-security.kubernetes.io/warn-version"  = local.k8s_pss_version
    }
  }
}

### Harbor
resource "helm_release" "harbor" {

  name             = "harbor"
  repository       = "https://helm.goharbor.io"
  chart            = "harbor"
  version          = var.harbor_version
  namespace        = kubernetes_namespace.harbor_namespace.metadata[0].name
  create_namespace = false
  timeout          = local.helm_default_timeout

  values = [
    templatefile(
      "${path.module}/helm_values/harbor.yaml",
      {
        harbor_url      = var.harbor_url
        harbor_password = var.harbor_password
        storage_class   = var.storage_class_name
      }
    )
  ]

  atomic = true
  wait   = true
}

### Argo CD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = kubernetes_namespace.argocd_namespace.metadata[0].name
  create_namespace = false
  timeout          = local.helm_default_timeout

  values = [
    templatefile(
      "${path.module}/helm_values/argocd.yaml",
      {
        argocd_url                   = var.argocd_url
        argocd_admin_password_bcrypt = bcrypt(var.argocd_admin_password)
        storage_class                = var.storage_class_name
      }
    )
  ]

  atomic = true
  wait   = true
}

### Jenkins
resource "helm_release" "jenkins" {
  name             = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = var.jenkins_version
  namespace        = kubernetes_namespace.jenkins_namespace.metadata[0].name
  create_namespace = false
  timeout          = local.helm_default_timeout

  values = [
    templatefile(
      "${path.module}/helm_values/jenkins.yaml",
      {
        jenkins_agent_namespace            = local.jenkins_agent_namespace
        jenkins_agent_service_account_name = local.jenkins_agent_service_account_name
        storage_class                      = var.storage_class_name
      }
    ),
    templatefile(
      "${path.module}/helm_values/jenkins-controller.yaml",
      {
        jenkins_url                             = var.jenkins_url
        jenkins_admin_username                  = var.jenkins_admin_username
        jenkins_admin_password                  = var.jenkins_admin_password
        jenkins_controller_service_account_name = local.jenkins_controller_service_account_name
        jenkins_pipeline_repository_url         = var.jenkins_pipeline_repository_url
        jenkins_pipeline_repository_branch      = var.jenkins_pipeline_repository_branch
        jenkins_pipeline_script_path            = var.jenkins_pipeline_script_path
      }
    )
  ]

  atomic = true
  wait   = true

  depends_on = [
    kubernetes_role_binding.jenkins_controller_schedule_agents,
    kubernetes_service_account.jenkins_agent,
  ]
}

### Plane Community Edition
resource "random_password" "plane_secret_key" {
  count   = var.plane_enabled ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "plane_live_server_secret_key" {
  count   = var.plane_enabled ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "plane_postgres_password" {
  count   = var.plane_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "plane_rabbitmq_password" {
  count   = var.plane_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "plane_minio_password" {
  count   = var.plane_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "helm_release" "plane" {
  count = var.plane_enabled ? 1 : 0

  name             = "plane"
  repository       = "https://helm.plane.so/"
  chart            = "plane-ce"
  version          = var.plane_version
  namespace        = kubernetes_namespace.plane_namespace[0].metadata[0].name
  create_namespace = false
  timeout          = 900

  values = [
    templatefile(
      "${path.module}/helm_values/plane.yaml",
      {
        plane_url                    = var.plane_url
        storage_class                = var.storage_class_name
        plane_secret_key             = random_password.plane_secret_key[0].result
        plane_live_server_secret_key = random_password.plane_live_server_secret_key[0].result
        postgres_password            = random_password.plane_postgres_password[0].result
        rabbitmq_password            = random_password.plane_rabbitmq_password[0].result
        minio_password               = random_password.plane_minio_password[0].result
        plane_admin_email            = var.plane_admin_email
        plane_admin_password         = var.plane_admin_password
      }
    )
  ]

  atomic        = true
  wait          = true
  wait_for_jobs = true
}


