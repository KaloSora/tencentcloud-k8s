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

  provisioner "local-exec" {
    when = destroy

    environment = {
      KUBE_CONFIG   = var.kubeconfig_path
      STORAGE_CLASS = var.cfs_storage_class_name
    }

    command = <<-EOT
      set -Eeuo pipefail

      echo "============================================================"
      echo "CFS PVC Cleanup"
      echo "============================================================"

      export KUBECONFIG="$KUBE_CONFIG"

      echo "Kubeconfig : $KUBE_CONFIG"
      echo "StorageClass: $STORAGE_CLASS"

      # --------------------------------------------------------
      # Pre-check
      # --------------------------------------------------------

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

      # ------------------------------------------------------
      # Delete PVCs
      # ------------------------------------------------------
      kubectl delete pvc --all

      # --------------------------------------------------------
      # Wait for PV cleanup
      # --------------------------------------------------------
      echo
      echo ">>> Waiting for PV cleanup..."

      elapsed=0

      while [ "$elapsed" -lt "$timeout" ]; do

        PV_COUNT="$(
          kubectl get pv \
            -o jsonpath='{range .items[*]}{.spec.storageClassName}{"\n"}{end}' \
            | grep -Fx "$STORAGE_CLASS" \
            | wc -l \
            | tr -d ' '
        )"

        if [ "$PV_COUNT" -eq 0 ]; then
          echo "[PASS] All CFS PVs have been deleted."
          break
        fi

        echo "[WAIT] $PV_COUNT CFS PV(s) still exist."

        sleep "$interval"
        elapsed=$((elapsed + interval))
      done

      if [ "$PV_COUNT" -ne 0 ]; then
        echo
        echo "[ERROR] CFS PV cleanup timed out after ${timeout}s."
        kubectl get pv
        exit 1
      fi

      echo
      echo "[PASS] CFS PVC/PV cleanup completed."
    EOT
  }
}