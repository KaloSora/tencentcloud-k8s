#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Tencent Cloud K8s - Terraform Create
#
# Local environment:
#   macOS
#
# Usage:
#
#   export TF_VAR_secret_id="YOUR_SECRET_ID"
#   export TF_VAR_secret_key="YOUR_SECRET_KEY"
#
#   ./scripts/create.sh
#
# Terraform Runbook:
#
#   1. terraform init
#   2. module.k8s_cvm
#   3. module.k8s_cfs
#   4. module.k8s_ingress
#   5. module.k8s_monitoring
#   6. module.k8s_cicd
# ============================================================

set -o pipefail

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

run_step() {
    local step="$1"
    shift

    echo
    echo "------------------------------------------------------------"
    echo "STEP ${step}"
    echo "------------------------------------------------------------"

    echo "+ $*"

    "$@"

    echo "[PASS] STEP ${step}"
}

# ------------------------------------------------------------
# Pre-check
# ------------------------------------------------------------

log "Tencent Cloud K8s - CREATE"

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

echo "Project root       : ${PROJECT_ROOT}"
echo "Terraform directory: ${TF_DIR}"
echo "Variable file      : ${TF_VAR_FILE}"
echo "Backend bucket     : ${TF_BACKEND_BUCKET}"
echo "Backend region     : ${TF_BACKEND_REGION}"

# ------------------------------------------------------------
# STEP 1 - Terraform Init
# ------------------------------------------------------------

log "STEP 1/6 - Terraform Init"

terraform init \
    -backend-config="bucket=${TF_BACKEND_BUCKET}" \
    -backend-config="region=${TF_BACKEND_REGION}" \
    -backend-config="secret_id=${TF_VAR_secret_id}" \
    -backend-config="secret_key=${TF_VAR_secret_key}"

echo "[PASS] Terraform initialization completed"

# ------------------------------------------------------------
# Terraform Validate
# ------------------------------------------------------------

log "Terraform Validate"

terraform validate

echo "[PASS] Terraform configuration is valid"

# ------------------------------------------------------------
# STEP 2 - Kubernetes CVM
# ------------------------------------------------------------

run_step "2/6 - Deploy Kubernetes on CVM" \
    terraform apply \
    -target=module.k8s_cvm \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# STEP 3 - CFS CSI
# ------------------------------------------------------------

run_step "3/6 - Create K8s Storage with CFS CSI" \
    terraform apply \
    -target=module.k8s_cfs \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# STEP 4 - Ingress NGINX
# ------------------------------------------------------------

run_step "4/6 - Deploy Ingress NGINX" \
    terraform apply \
    -target=module.k8s_ingress \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# STEP 5 - Monitoring
# ------------------------------------------------------------

run_step "5/6 - Deploy Monitoring Framework" \
    terraform apply \
    -target=module.k8s_monitoring \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# STEP 6 - CICD
# ------------------------------------------------------------

run_step "6/6 - Deploy Kubernetes CICD" \
    terraform apply \
    -target=module.k8s_cicd \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# Final State
# ------------------------------------------------------------

log "Terraform State"

terraform state list

log "Terraform Outputs"

terraform output || true

# ------------------------------------------------------------
# Completed
# ------------------------------------------------------------

log "CREATE COMPLETED"

echo
echo "Kubernetes infrastructure has been successfully deployed."
echo
echo "Next step:"
echo
echo "  ./scripts/verify.sh"
echo