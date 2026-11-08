# Install custom resources in a separate release after Argo CD has installed
# its CRDs. Only the bootstrap resources are owned by Terraform/Helm;
# business AppProjects are reconciled by Argo CD from the GitOps repository.
resource "helm_release" "argocd_bootstrap" {
  count = contains(local.enabled_component_names, "argocd") && var.argocd_gitops_repo_url != "" ? 1 : 0

  name             = "argocd-bootstrap"
  namespace        = kubernetes_namespace.component["argocd"].metadata[0].name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  version          = "2.0.5"
  create_namespace = false
  wait             = true
  atomic           = true
  timeout          = 300

  values = [yamlencode({
    projects = {
      gitops-bootstrap = {
        namespace   = kubernetes_namespace.component["argocd"].metadata[0].name
        sourceRepos = [var.argocd_gitops_repo_url]
        destinations = [{
          server    = "https://kubernetes.default.svc"
          namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        }]
        clusterResourceWhitelist = []
        namespaceResourceWhitelist = [{
          group = "argoproj.io"
          kind  = "AppProject"
          }, {
          group = "argoproj.io"
          kind  = "Application"
        }]
      }
    }
    applications = {
      gitops-applications = {
        namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        project   = "gitops-bootstrap"
        source = {
          repoURL        = var.argocd_gitops_repo_url
          targetRevision = "main"
          path           = "argocd/applications"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        }
        syncPolicy = {
          automated = {
            prune    = false
            selfHeal = true
          }
        }
      }
      gitops-projects = {
        namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        project   = "gitops-bootstrap"
        source = {
          repoURL        = var.argocd_gitops_repo_url
          targetRevision = "main"
          path           = "argocd/projects"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        }
        syncPolicy = {
          automated = {
            prune    = false
            selfHeal = true
          }
        }
      }
    }
  })]

  depends_on = [module.component["argocd"]]
}

# Independent entry point: preserve the existing business GitOps bootstrap.
resource "helm_release" "argocd_infra_bootstrap" {
  count = contains(local.enabled_component_names, "argocd") && var.argocd_infra_gitops_repo_url != "" ? 1 : 0

  name             = "argocd-infra-bootstrap"
  namespace        = kubernetes_namespace.component["argocd"].metadata[0].name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  version          = "2.0.5"
  create_namespace = false
  wait             = true
  atomic           = true
  timeout          = 300

  values = [yamlencode({
    projects = {
      infra-gitops-bootstrap = {
        namespace   = kubernetes_namespace.component["argocd"].metadata[0].name
        sourceRepos = [var.argocd_infra_gitops_repo_url]
        destinations = [{
          server    = "https://kubernetes.default.svc"
          namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        }]
        clusterResourceWhitelist = []
        namespaceResourceWhitelist = [{
          group = "argoproj.io"
          kind  = "AppProject"
          }, {
          group = "argoproj.io"
          kind  = "Application"
        }]
      }
    }
    applications = {
      infra-gitops-applications = {
        namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        project   = "infra-gitops-bootstrap"
        source = {
          repoURL        = var.argocd_infra_gitops_repo_url
          targetRevision = "main"
          path           = "argocd/applications"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        }
        syncPolicy = {
          automated = {
            prune    = false
            selfHeal = true
          }
        }
      }
      infra-gitops-projects = {
        namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        project   = "infra-gitops-bootstrap"
        source = {
          repoURL        = var.argocd_infra_gitops_repo_url
          targetRevision = "main"
          path           = "argocd/projects"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = kubernetes_namespace.component["argocd"].metadata[0].name
        }
        syncPolicy = {
          automated = {
            prune    = false
            selfHeal = true
          }
        }
      }
    }
  })]

  lifecycle {
    precondition {
      condition     = contains(local.enabled_component_names, "crossplane")
      error_message = "Infrastructure GitOps bootstrap requires the crossplane component to be enabled."
    }
  }

  # Wait for both controllers and the Crossplane core CRDs. Provider CRDs
  # require a separate readiness gate before syncing dependent declarations.
  depends_on = [module.component, kubernetes_secret_v1.crossplane_tencentcloud]
}
