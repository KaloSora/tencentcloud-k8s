#!/bin/bash

setup_k8s (){
    set -e
    echo "=== Start to Install K8s ==="

    echo "=== End to Install K8s ==="
}

output() {
    echo "K3s Instance IP: ${instance_ip}"
    echo "K3s Instance ID: ${instance_id}"
    echo "Execute cmd to connect server: ssh -i k3s-cvm/ssh_key/cvm_key.pem ubuntu@${instance_ip}"
}

main() {
    echo "Setup K3s ..."
    setup_k8s
    
    output
}

main