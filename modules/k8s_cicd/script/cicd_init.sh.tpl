#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH

install_ingress_nginx() {
    echo "Installing Ingress Nginx ..."

    helm install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress \
            --create-namespace \
            --version "$INGRESS_NGINX_VERSION" \
            --set controller.hostNetwork=true,controller.dnsPolicy=ClusterFirstWithHostNet,controller.kind=DaemonSet,controller.ingressClassResource.default=true \
            --set-string controller.image.digest=""

    echo "Checking Ingress Nginx status ..."
    helm list -n ingress
    kubectl get pod -n ingress

}

main() {
    echo "Start to initialize K8s CICD ..."
    install_ingress_nginx
}

main