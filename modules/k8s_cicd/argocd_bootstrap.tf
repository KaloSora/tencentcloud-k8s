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
        }]
      }
    }
    applications = {
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
