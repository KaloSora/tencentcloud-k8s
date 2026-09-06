#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Tencent Cloud K8s - Terraform Destroy
#
# Local environment:
#   macOS
#
# Usage:
#
#   export TF_VAR_secret_id="YOUR_SECRET_ID"
#   export TF_VAR_secret_key="YOUR_SECRET_KEY"
#
#   ./scripts/destroy.sh
#
# Destroy order:
#
#   1. module.k8s_cicd
#   2. module.k8s_monitoring
#   3. module.k8s_ingress
#   4. module.k8s_cfs
#   5. module.k8s_cvm
# ============================================================

# ------------------------------------------------------------
# Project paths
# ------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TF_DIR="${PROJECT_ROOT}"
TF_VAR_FILE="dev.tfvars"

# ------------------------------------------------------------
# Tencent Cloud Terraform Backend
# ------------------------------------------------------------

TF_BACKEND_BUCKET="cvm-k8s-config-1304007562"
TF_BACKEND_REGION="ap-guangzhou"

# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------

log() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

error() {
    echo
    echo "[ERROR] $1" >&2
    exit 1
}

run_destroy() {
    local step="$1"
    local module="$2"

    echo
    echo "------------------------------------------------------------"
    echo "STEP ${step}/5 - Destroy ${module}"
    echo "------------------------------------------------------------"

    terraform destroy \
        -target="${module}" \
        -var-file="${TF_VAR_FILE}" \
        -auto-approve

    echo "[PASS] ${module} destroyed"
}

# ------------------------------------------------------------
# Pre-check
# ------------------------------------------------------------

log "Tencent Cloud K8s - DESTROY"

command -v terraform >/dev/null 2>&1 || \
    error "terraform command not found"

[[ -n "${TF_VAR_secret_id:-}" ]] || \
    error "TF_VAR_secret_id is not set"

[[ -n "${TF_VAR_secret_key:-}" ]] || \
    error "TF_VAR_secret_key is not set"

[[ -d "${TF_DIR}" ]] || \
    error "Terraform directory not found: ${TF_DIR}"

[[ -f "${TF_DIR}/${TF_VAR_FILE}" ]] || \
    error "Terraform variable file not found: ${TF_DIR}/${TF_VAR_FILE}"

cd "${TF_DIR}"

# ------------------------------------------------------------
# Terraform Init
# ------------------------------------------------------------

log "Terraform Init"

terraform init \
    -backend-config="bucket=${TF_BACKEND_BUCKET}" \
    -backend-config="region=${TF_BACKEND_REGION}" \
    -backend-config="secret_id=${TF_VAR_secret_id}" \
    -backend-config="secret_key=${TF_VAR_secret_key}"

echo "[PASS] Terraform initialization completed"

# ------------------------------------------------------------
# Confirmation
# ------------------------------------------------------------

log "DESTROY WARNING"

echo "The following Terraform modules will be destroyed:"
echo
echo "  1. module.k8s_cicd"
echo "  2. module.k8s_monitoring"
echo "  3. module.k8s_ingress"
echo "  4. module.k8s_cfs"
echo "  5. module.k8s_cvm"
echo
echo "This operation is DESTRUCTIVE."
echo

if [[ "${TF_AUTO_APPROVE:-false}" != "true" ]]; then

    read -r -p "Type 'destroy' to continue: " CONFIRM

    if [[ "${CONFIRM}" != "destroy" ]]; then
        echo
        echo "Destroy cancelled."
        exit 0
    fi

fi

# ------------------------------------------------------------
# Destroy
# ------------------------------------------------------------

run_destroy "1" "module.k8s_cicd"

run_destroy "2" "module.k8s_monitoring"

run_destroy "3" "module.k8s_ingress"

run_destroy "4" "module.k8s_cfs"

run_destroy "5" "module.k8s_cvm"

# ------------------------------------------------------------
# Final State
# ------------------------------------------------------------

log "Final Terraform State"

REMAINING="$(terraform state list 2>/dev/null || true)"

if [[ -z "${REMAINING}" ]]; then

    echo "[PASS] Terraform state is empty."

else

    echo "[WARNING] Terraform state still contains resources:"
    echo
    echo "${REMAINING}"

fi

log "DESTROY COMPLETED"