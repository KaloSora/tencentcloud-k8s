locals {
  storage_class_name = "cfs-shared-storageclass"
  helm_default_timeout = 600
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
    <<-EOT
      controller:
        healthCheck:
          initialDelaySeconds: 60
          periodSeconds: 10
        hostNetwork: true
        dnsPolicy: ClusterFirstWithHostNet
        kind: DaemonSet
        ingressClassResource:
          default: true
        image:
          digest: ""
        service:
          type: ClusterIP
        nodeSelector:
          "purpose": "devops"
    EOT
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
#     <<-EOT
#       expose:
#         type: ingress
#         tls:
#           enabled: true
#           certSource: "auto"
#           secret:
#             secretName: "harbor-tls"
#         ingress:
#           className: "nginx"
#           hosts:
#             core: "${var.harbor_url}"
#           annotations:
#             nginx.ingress.kubernetes.io/ssl-redirect: "true"
#             nginx.ingress.kubernetes.io/proxy-body-size: "0"
#       externalURL: "https://${var.harbor_url}"
#       harborAdminPassword: "${var.harbor_password}"

#       nodeSelector:
#         "purpose": "devops"

#       ### PVC settings
#       persistence:
#         enabled: true
#         resourcePolicy: "delete"
#         persistentVolumeClaim:
#           registry:
#             storageClass: "${local.storage_class_name}"
#             size: "100Gi"
#           jobservice:
#             jobLog:
#               storageClass: "${local.storage_class_name}"
#               size: "1Gi"
#           trivy:
#             storageClass: "${local.storage_class_name}"
#             size: "5Gi"
#           database:
#             storageClass: "${local.storage_class_name}"
#             size: "10Gi"
#           redis:
#             storageClass: "${local.storage_class_name}"
#             size: "5Gi"

#       ### Resource limit
#       core:
#         resources:
#           requests:
#             memory: "512Mi"
#             cpu: "500m"
#       registry:
#         resources:
#           requests:
#             memory: "256Mi"
#             cpu: "200m"
#     EOT
#   ]
# }

### Grafana & Loki Stack
resource "helm_release" "loki_stack" {
  depends_on = [kubernetes_storage_class.cfs_shared]

  name       = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_version
  namespace  = "grafana-loki"
  create_namespace = true
  timeout    = local.helm_default_timeout

  values = [
    <<-EOT
      loki:
        persistence:
          enabled: true
          storageClassName: "${local.storage_class_name}"
          size: 50Gi
        config:
          table_manager:
            retention_period: 168h
        nodeSelector:
          "purpose": "devops"

      promtail:
        enabled: true
        resources:
          requests:
            memory: 128Mi
            cpu: 100m
          limits:
            memory: 512Mi
            cpu: 300m
    EOT
  ]
}

resource "helm_release" "grafana" {
  depends_on = [
    helm_release.ingress_nginx,
    kubernetes_storage_class.cfs_shared
  ]

  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_version
  namespace  = "grafana-monitor"
  create_namespace = true
  timeout    = local.helm_default_timeout

  values = [
    <<-EOT
      persistence:
        enabled: true
        storageClassName: "${local.storage_class_name}"
        size: 10Gi

      service:
        type: ClusterIP
        port: 80

      adminPassword: "${var.grafana_password}"

      nodeSelector:
        "purpose": "devops"

      ingress:
        enabled: true
        ingressClassName: nginx
        hosts:
          - "${var.grafana_url}"
        path: /
        pathType: Prefix

      resources:
        requests:
          memory: 512Mi
          cpu: 200m
        limits:
          memory: 1536Mi
          cpu: "1"
    EOT
  ]
}