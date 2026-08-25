locals {
  storage_class_name = "cfs-shared-storageclass"
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

### Set ingress-nginx service type to ClusterIP
### This is to avoid the issue of LoadBalancer service type to pending status and stuck terraform provider
### Health check: http://NodeIP:10254/healthz
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  repository       = "https://helm-charts.itboon.top/ingress-nginx"
  # repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  timeout          = 300

  values = [
    <<-EOT
      controller:
        healthCheck:
          initialDelaySeconds: 10
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
    EOT
  ]
}