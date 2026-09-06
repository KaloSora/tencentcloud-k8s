locals {
  helm_default_timeout = 600
}


### Harbor
resource "helm_release" "harbor" {

  name             = "harbor"
  repository       = "https://helm.goharbor.io"
  chart            = "harbor"
  version          = var.harbor_version
  namespace        = "harbor"
  create_namespace = true
  timeout          = local.helm_default_timeout

  values = [
    templatefile(
      "${path.module}/helm_values/harbor.yaml", 
      {
        harbor_url     = var.harbor_url
        harbor_password = var.harbor_password
        storage_class  = var.storage_class_name
      }
    )
  ]
}

### Remove stand alone Grafana helm release
# resource "helm_release" "grafana" {
#   depends_on = [
#     helm_release.ingress_nginx,
#     kubernetes_storage_class.cfs_shared
#   ]

#   name       = "grafana"
#   repository = "https://grafana.github.io/helm-charts"
#   chart      = "grafana"
#   version    = var.grafana_version
#   namespace  = local.monitoring_namespace
#   create_namespace = true
#   timeout    = local.helm_default_timeout

#   values = [
#     <<-EOT
#       persistence:
#         enabled: true
#         storageClassName: "${local.storage_class_name}"
#         size: 10Gi

#       service:
#         type: ClusterIP
#         port: 80

#       adminPassword: "${var.grafana_password}"

#       nodeSelector:
#         "purpose": "devops"

#       ingress:
#         enabled: true
#         ingressClassName: nginx
#         hosts:
#           - "${var.grafana_url}"
#         path: /
#         pathType: Prefix

#       resources:
#         requests:
#           memory: 512Mi
#           cpu: 200m
#         limits:
#           memory: 1536Mi
#           cpu: "1"

#       datasources:
#         datasources.yaml:
#           apiVersion: 1
#           datasources:
#           - name: Loki
#             type: loki
#             url: http://loki.${local.monitoring_namespace}.svc.cluster.local:3100
#             access: proxy
#             isDefault: false
#             jsonData:
#               queryLanguage: "LogQL"
#     EOT
#   ]
# }


