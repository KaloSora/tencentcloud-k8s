#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH

create_storage_class() {
    echo "Creating K8s storage class ..."

    if [ ! -f "${STORAGE_CLASS_YAML}" ]; then
        echo "ERROR: STORAGE_CLASS_YAML not found: ${STORAGE_CLASS_YAML}"
        exit 1
    else
        kubectl apply -f "${STORAGE_CLASS_YAML}"

        echo "Checking K8s storage class ..."
        kubectl get sc
    fi
}

install_ingress_nginx() {
    echo "Installing Ingress Nginx ..."

    helm install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --version "${INGRESS_NGINX_VERSION}" \
            --set controller.hostNetwork=true,controller.dnsPolicy=ClusterFirstWithHostNet,controller.kind=DaemonSet,controller.ingressClassResource.default=true \
            --set-string controller.image.digest=""

    echo "Checking Ingress Nginx status ..."
    helm list -n ingress
    kubectl get pod -n ingress

}

install_harbor() {
    echo "Installing Harbor ..."

    helm repo add harbor https://helm.goharbor.io
    helm repo update

    CORE_SECRET=$(openssl rand -hex 16)
    JOBSERVICE_SECRET=$(openssl rand -hex 16)
    PORTAL_SECRET=$(openssl rand -hex 16)
    REGISTRY_SECRET=$(openssl rand -hex 16)

    helm install harbor harbor/harbor \
        --namespace harbor \
        --create-namespace \
        --version "${HARBOR_VERSION}" \
        --set expose.type=ingress \
        --set expose.tls.enabled=false \
        --set externalURL=http://${HARBOR_URL} \
        --set harborAdminPassword=Harbor12345 \
        --set notary.enabled=false \
        --set chartmuseum.enabled=false \
        --set core.secretkey="$CORE_SECRET" \
        --set jobservice.secretkey="$JOBSERVICE_SECRET" \
        --set portal.secretkey="$PORTAL_SECRET" \
        --set registry.secretkey="$REGISTRY_SECRET" \
        --set persistence.enabled=true \
        --set persistence.storageClass="${STORAGE_CLASS_NAME}" \
        --set persistence.size=50Gi \
        --set persistence.registry.size=100Gi \
        --set persistence.jobservice.size=20Gi \
        --set persistence.database.size=20Gi \
        --set persistence.redis.size=10Gi \
        --set ingress.hosts[0].name=${HARBOR_URL} \
        --set ingress.hosts[0].path=/ \
        --set ingress.ingressClassName=nginx
}

main() {
    echo "Start to initialize K8s CICD ..."
    create_storage_class
    install_ingress_nginx
}

main