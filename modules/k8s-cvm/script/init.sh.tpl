#!/bin/bash

init() {
    # Replace the mirror source of Rocky Linux with Aliyun mirror
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
    -i.bak \
    /etc/yum.repos.d/[Rr]ocky*.repo
    dnf makecache

    # Replace firewalld with iptables
    systemctl stop firewalld
    systemctl disable firewalld
    yum -y install iptables-services
    systemctl start iptables
    iptables -F
    systemctl enable iptables

    # Disabled Selinux
    setenforce 0
    sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
    grubby --update-kernel ALL --args selinux=0

    # Set timezone
    timedatectl set-timezone Asia/Shanghai
}

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

    echo "Init Rocky Linux setting ..."
    init

    echo "Setup K3s ..."
    setup_k8s
    
    output
}

main