locals {
  storage_class_name = "cfs-shared-storageclass"
  helm_default_timeout = 900
  monitoring_namespace = "monitoring"
}

### K8s storageClass with CFS CSI provider
resource "kubernetes_storage_class" "cfs_shared" {
  metadata {
    name = local.storage_class_name
  }

  storage_provisioner = "com.tencent.cloud.csi.cfs"
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"

  mount_options = [
    "vers=3",
    "nolock",
    "proto=tcp",
    "noresvport"
  ]

  parameters = {
    vpcId       = var.vpc_id
    subnetId    = var.subnet_id
    storageType = "SD"
    pgroupid    = var.cfs_pgroup_id
  }
}

# resource "tencentcloud_clb_instance" "k8s_clb" {
#   clb_name = "my-pay-as-you-go-clb"
#   network_type = "OPEN"
#   # charge_type = "POSTPAID_BY_HOUR"
#   internet_charge_type = "TRAFFIC_POSTPAID_BY_HOUR"
#   internet_bandwidth_max_out = 10
#   vpc_id    = var.vpc_id
#   subnet_id = var.subnet_id
# }

### Set ingress-nginx service type to ClusterIP
### This is to avoid the issue of LoadBalancer service type to pending status and stuck terraform provider
### Health check: http://NodeIP:10254/healthz
resource "helm_release" "ingress_nginx" {
  
  depends_on = [kubernetes_storage_class.cfs_shared]

  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  timeout          = local.helm_default_timeout

  values = [
    file("${path.module}/helm_values/ingress-nginx.yaml")
  ]
}

### Harbor 
### Temporarily disable harbor helm chart installation for testing
# resource "helm_release" "harbor" {

#   depends_on = [helm_release.ingress_nginx, kubernetes_storage_class.cfs_shared]

#   name             = "harbor"
#   repository       = "https://helm.goharbor.io"
#   chart            = "harbor"
#   version          = var.harbor_version
#   namespace        = "harbor"
#   create_namespace = true
#   timeout          = local.helm_default_timeout

#   values = [
#     templatefile(
#       "${path.module}/helm_values/harbor.yaml", 
#       {
#         harbor_url     = var.harbor_url
#         harbor_password = var.harbor_password
#         storage_class  = local.storage_class_name
#       }
#     )
#   ]
# }

### Grafana & Loki Stack
resource "helm_release" "loki_stack" {
  depends_on = [kubernetes_storage_class.cfs_shared]

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_version
  namespace  = local.monitoring_namespace
  create_namespace = true
  timeout    = local.helm_default_timeout

  values = [
    templatefile(
      "${path.module}/helm_values/loki.yaml",
      {
        storage_class_name = local.storage_class_name
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

### kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version

  namespace        = local.monitoring_namespace
  create_namespace = true

  timeout = local.helm_default_timeout

  depends_on = [
    kubernetes_storage_class.cfs_shared,
    helm_release.ingress_nginx
  ]

    values = [
    templatefile(
      "${path.module}/helm_values/kube_prometheus_stack.yaml",
      {
        storage_class_name = local.storage_class_name
        grafana_password = var.grafana_password
        grafana_url = var.grafana_url
        monitoring_namespace = local.monitoring_namespace
      }
    )
  ]
}
