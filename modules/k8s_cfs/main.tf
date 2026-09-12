# Create CFS access group
resource "tencentcloud_cfs_access_group" "k8s_cfs_ag" {
  name        = "k8s-cfs-ag"
  description = "Allow K8s cluster nodes to access"
}

# CFS Access rules for each CVM private IP
resource "tencentcloud_cfs_access_rule" "k8s_cfs_rule" {

  access_group_id = tencentcloud_cfs_access_group.k8s_cfs_ag.id
  auth_client_ip  = var.cfs_cidr
  priority        = 1
  rw_permission   = "RW"
  user_permission = "no_all_squash"
}

resource "kubernetes_storage_class" "cfs_shared" {

  metadata {
    name = var.cfs_storage_class_name
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
    pgroupid    = tencentcloud_cfs_access_group.k8s_cfs_ag.id
  }
}


### Add PVC cleanup resource to release CFS resources when destroying the cluster
resource "terraform_data" "cfs_pvc_cleanup" {

  input = {
    kube_config   = var.kubeconfig_path
    storage_class = var.cfs_storage_class_name
    timeout       = 300
    interval      = 10
  }

  # Will destroy all PVCs before destroying the storage class
  depends_on = [
    kubernetes_storage_class.cfs_shared
  ]

  provisioner "local-exec" {
    when = destroy

    environment = {
      KUBE_CONFIG   = self.input.kube_config
      STORAGE_CLASS = self.input.storage_class
      TIMEOUT       = self.input.timeout
      INTERVAL      = self.input.interval
    }

    command = <<-EOT
      set -Eeuo pipefail

      export KUBECONFIG="$KUBE_CONFIG"

      echo "============================================================"
      echo "CFS PVC Cleanup"
      echo "============================================================"

      if ! command -v kubectl >/dev/null 2>&1; then
        echo "[ERROR] kubectl command not found"
        exit 1
      fi

      if [ ! -f "$KUBECONFIG" ]; then
        echo "[ERROR] kubeconfig not found: $KUBECONFIG"
        exit 1
      fi

      if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "[ERROR] Unable to connect to Kubernetes cluster"
        exit 1
      fi

      echo ">>> Deleting PVCs using StorageClass: $STORAGE_CLASS"

      kubectl get pvc \
        --all-namespaces \
        -o jsonpath='{range .items[?(@.spec.storageClassName=="'$STORAGE_CLASS'")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
        | while read -r namespace pvc; do
            if [ -n "$namespace" ] && [ -n "$pvc" ]; then
              echo "[DELETE] PVC $namespace/$pvc"
              kubectl delete pvc "$pvc" \
                -n "$namespace" \
                --ignore-not-found
            fi
          done

      sleep 30

      echo
      echo "[PASS] CFS PVC cleanup completed."
      echo "PV and backend CFS resources will be reclaimed by the CSI driver."

    EOT
  }
}