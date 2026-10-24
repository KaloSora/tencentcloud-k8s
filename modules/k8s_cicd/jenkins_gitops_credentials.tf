locals {
  jenkins_gitops_values = local.jenkins_enabled ? [yamlencode({
    controller = {
      # Secret-backed environment variables are refreshed only when the pod restarts.
      podAnnotations = {
        "checksum/gitops-token" = sha256(var.gitops_github_token)
      }
      containerEnv = [{
        name = "GITOPS_GITHUB_TOKEN"
        valueFrom = {
          secretKeyRef = {
            name = kubernetes_secret_v1.jenkins_gitops[0].metadata[0].name
            key  = "token"
          }
        }
      }]
      JCasC = {
        configScripts = {
          gitops-credentials = yamlencode({
            credentials = {
              system = {
                domainCredentials = [{
                  credentials = [{
                    string = {
                      scope       = "GLOBAL"
                      id          = var.gitops_credentials_id
                      description = "GitOps promotion GitHub token managed by Terraform and JCasC"
                      secret      = "$${GITOPS_GITHUB_TOKEN}"
                    }
                  }]
                }]
              }
            }
            jenkins = {
              globalNodeProperties = [{
                envVars = {
                  env = [{
                    key   = "JENKINS_GITOPS_CREDENTIALS_ID"
                    value = var.gitops_credentials_id
                  }]
                }
              }]
            }
          })
        }
      }
    }
  })] : []
}

# Keep the token out of Helm values and JCasC ConfigMaps. Terraform still stores
# this Secret's data in state; sensitive=true does not encrypt state contents.
resource "kubernetes_secret_v1" "jenkins_gitops" {
  count = local.jenkins_enabled ? 1 : 0

  metadata {
    name      = "jenkins-gitops-github-token"
    namespace = kubernetes_namespace.component["jenkins"].metadata[0].name
  }
  type = "Opaque"
  data = { token = var.gitops_github_token }
}
