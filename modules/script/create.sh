#!/usr/bin/env bash

# Import tencentcloud secret key
source ~/tencentcloud_env.sh

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
#   6. module.k8s_app
#   7. module.k8s_cicd
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
# Optional modules
#
# Set either value to false to skip deploying that module.
# ------------------------------------------------------------

DEPLOY_MONITORING="${DEPLOY_MONITORING:-false}"
DEPLOY_CICD="${DEPLOY_CICD:-true}"

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

tf_console_value() {
    local expression="$1"
    local value

    if ! value="$(terraform console -var-file="${TF_VAR_FILE}" <<< "${expression}" 2>/dev/null)"; then
        echo "<unavailable>"
        return 0
    fi

    # Decode Terraform string escapes so service access values are displayed
    # exactly, rather than as HCL string literals.
    if ! printf '%s' "${value}" | python3 -c '
import json, sys
value = json.load(sys.stdin)
print(value if isinstance(value, str) else json.dumps(value))
'; then
        echo "<unavailable>"
    fi
}

validate_boolean() {
    local name="$1"
    local value="$2"

    case "${value}" in
        true|false) ;;
        *) error "${name} must be true or false, got: ${value}" ;;
    esac
}

# ------------------------------------------------------------
# Pre-check
# ------------------------------------------------------------

log "Tencent Cloud K8s - CREATE"

command -v terraform >/dev/null 2>&1 || \
    error "terraform command not found"

command -v python3 >/dev/null 2>&1 || \
    error "python3 command not found (required to decode service access values)"

[[ -n "${TF_VAR_secret_id:-}" ]] || \
    error "TF_VAR_secret_id is not set"

[[ -n "${TF_VAR_secret_key:-}" ]] || \
    error "TF_VAR_secret_key is not set"

[[ -d "${TF_DIR}" ]] || \
    error "Terraform directory not found: ${TF_DIR}"

[[ -f "${TF_DIR}/${TF_VAR_FILE}" ]] || \
    error "Terraform variable file not found: ${TF_DIR}/${TF_VAR_FILE}"

validate_boolean "DEPLOY_MONITORING" "${DEPLOY_MONITORING}"
validate_boolean "DEPLOY_CICD" "${DEPLOY_CICD}"

cd "${TF_DIR}"

echo "Project root       : ${PROJECT_ROOT}"
echo "Terraform directory: ${TF_DIR}"
echo "Variable file      : ${TF_VAR_FILE}"
echo "Backend bucket     : ${TF_BACKEND_BUCKET}"
echo "Backend region     : ${TF_BACKEND_REGION}"
echo "Deploy monitoring  : ${DEPLOY_MONITORING}"
echo "Deploy CI/CD       : ${DEPLOY_CICD}"

# ------------------------------------------------------------
# STEP 1 - Terraform Init
# ------------------------------------------------------------

log "STEP 1/7 - Terraform Init"

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

run_step "2/7 - Deploy Kubernetes on CVM" \
    terraform apply \
    -target=module.k8s_cvm \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# STEP 3 - CFS CSI
# ------------------------------------------------------------

run_step "3/7 - Create K8s Storage with CFS CSI" \
    terraform apply \
    -target=module.k8s_cfs \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# STEP 4 - Ingress NGINX
# ------------------------------------------------------------

run_step "4/7 - Deploy Ingress NGINX" \
    terraform apply \
    -target=module.k8s_ingress \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# STEP 5 - Monitoring
# ------------------------------------------------------------

if [[ "${DEPLOY_MONITORING}" == "true" ]]; then
    run_step "5/7 - Deploy Monitoring Framework" \
        terraform apply \
        -target=module.k8s_monitoring \
        -var-file="${TF_VAR_FILE}" \
        -auto-approve
else
    echo "[SKIP] STEP 5/7 - Monitoring deployment is disabled"
fi

# ------------------------------------------------------------
# STEP 6 - Application promotion namespaces
# ------------------------------------------------------------

run_step "6/7 - Create Application Promotion Namespaces" \
    terraform apply \
    -target=module.k8s_app \
    -var-file="${TF_VAR_FILE}" \
    -auto-approve

# ------------------------------------------------------------
# STEP 7 - CICD and application registry access
# ------------------------------------------------------------

if [[ "${DEPLOY_CICD}" == "true" ]]; then
    run_step "7/7 - Deploy Kubernetes CICD and Application Registry Access" \
        terraform apply \
        -target=module.k8s_cicd \
        -var-file="${TF_VAR_FILE}" \
        -auto-approve
else
    echo "[SKIP] STEP 7/7 - CI/CD deployment is disabled"
fi

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

# ------------------------------------------------------------
# Service access summary
# ------------------------------------------------------------

if [[ "${DEPLOY_MONITORING}" == "true" || "${DEPLOY_CICD}" == "true" ]]; then
    log "SERVICE ACCESS"
fi

if [[ "${DEPLOY_MONITORING}" == "true" ]]; then
    GRAFANA_URL="$(tf_console_value 'var.helm_grafana_url')"

    echo
    echo "Grafana"
    echo "  URL             : http://${GRAFANA_URL}"
    echo "  Username        : admin"
fi

if [[ "${DEPLOY_CICD}" == "true" ]]; then
    JENKINS_URL="$(tf_console_value 'nonsensitive(var.cicd_components["jenkins"].config["jenkins_url"])')"
    JENKINS_USERNAME="$(tf_console_value 'nonsensitive(var.cicd_components["jenkins"].config["jenkins_admin_username"])')"
    ARGOCD_URL="$(tf_console_value 'nonsensitive(var.cicd_components["argocd"].config["argocd_url"])')"
    HARBOR_URL="$(tf_console_value 'nonsensitive(var.cicd_components["harbor"].config["harbor_url"])')"

    echo
    echo "Jenkins"
    echo "  URL             : http://${JENKINS_URL}"
    echo "  Username        : ${JENKINS_USERNAME}"

    echo
    echo "Argo CD"
    echo "  URL             : http://${ARGOCD_URL}"
    echo "  Username        : admin"

    echo
    echo "Harbor"
    echo "  URL             : http://${HARBOR_URL}"
    echo "  Username        : admin"

    PLANE_ENABLED="$(tf_console_value 'nonsensitive(var.cicd_components["plane"].enabled)')"

    if [[ "${PLANE_ENABLED}" == "true" ]]; then
        PLANE_URL="$(tf_console_value 'nonsensitive(var.cicd_components["plane"].config["plane_url"])')"
        PLANE_USERNAME="$(tf_console_value 'nonsensitive(var.cicd_components["plane"].config["plane_admin_email"])')"

        echo
        echo "Plane"
        echo "  URL             : http://${PLANE_URL}"
        echo "  Username        : ${PLANE_USERNAME}"
    fi
fi
