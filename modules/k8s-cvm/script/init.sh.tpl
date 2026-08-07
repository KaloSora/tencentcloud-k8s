#!/bin/bash

init() {
    # Replace the mirror source of Rocky Linux with Aliyun mirror
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
    -i.bak \
    /etc/yum.repos.d/[Rr]ocky*.repo
    dnf makecache

    # Replace firewalld with iptables (legacy mode)
    systemctl stop firewalld
    systemctl disable firewalld
    yum -y install iptables-services
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
    systemctl start iptables
    iptables -F
    systemctl enable iptables

    # Disable Selinux
    setenforce 0
    sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
    grubby --update-kernel ALL --args selinux=0

    # Disable swap (kubelet requirement)
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Set timezone
    timedatectl set-timezone Asia/Shanghai

    # Install nfs & mount cfs
    yum -y install nfs-utils rpcbind

    yum -y install telnet

    yum -y install git

    # Enable ipvs
    echo ">>> Enable IPVS modules"
    # Install ipset and ipvsadm
    dnf install -y ipset ipvsadm
    # Load kernel modules for IPVS
    cat <<EOF | tee /etc/modules-load.d/ipvs.conf
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF
    modprobe ip_vs
    modprobe ip_vs_rr
    modprobe ip_vs_wrr
    modprobe ip_vs_sh
    modprobe nf_conntrack
    
    # sysctl tuning for IPVS
    cat <<EOF | tee /etc/sysctl.d/99-ipvs.conf
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.forwarding = 1
EOF
    sysctl --system

    # Load kernel modules (overlay, br_netfilter)
    cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter

    # Configure sysctl for Kubernetes
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sysctl --system
}

install_cfssl () {
    echo "Installing CFSSL..."

    curl -sLo cfssl "https://github.com/cloudflare/cfssl/releases/download/v${k8s_cfssl_version}/cfssl_${k8s_cfssl_version}_linux_amd64"
    curl -sLo cfssljson "https://github.com/cloudflare/cfssl/releases/download/v${k8s_cfssl_version}/cfssljson_${k8s_cfssl_version}_linux_amd64"
    curl -sLo cfssl-certinfo "https://github.com/cloudflare/cfssl/releases/download/v${k8s_cfssl_version}/cfssl-certinfo_${k8s_cfssl_version}_linux_amd64"
    chmod +x cfssl cfssljson cfssl-certinfo
    sudo mv cfssl cfssljson cfssl-certinfo /usr/local/bin/

    echo "Installation completed. Versions:"
    cfssl version
    cfssljson -version 2>/dev/null || echo "cfssljson installed"
    cfssl-certinfo -version 2>/dev/null || echo "cfssl-certinfo installed"
}

install_helm() {
    echo "Installing Helm..."

    curl -sLo helm.tar.gz "https://get.helm.sh/helm-v${k8s_helm_version}-linux-amd64.tar.gz"
    tar -zxvf helm.tar.gz
    chmod +x linux-amd64/helm
    sudo mv linux-amd64/helm /usr/local/bin/helm

    echo "Installation completed. Version:"
    helm version
}

setup_k8s() {
    set -e
    echo "=== Start to Install K8s ==="

    K8S_VERSION="${k8s_version}"
    K8S_CIDR="${k8s_cidr}"

    # 1. Install docker engine
    dnf install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io
    # Configure Docker cgroup driver to systemd
    mkdir -p /etc/docker
    cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

    systemctl enable docker
    systemctl start docker

    # 2. Install cri-dockerd
    wget https://github.com/Mirantis/cri-dockerd/releases/download/v${k8s_cri_dockerd_version}/cri-dockerd-${k8s_cri_dockerd_version}.amd64.tgz
    tar -xzf cri-dockerd-${k8s_cri_dockerd_version}.amd64.tgz
    file cri-dockerd/cri-dockerd
    mv cri-dockerd/cri-dockerd /usr/local/bin/
    chmod +x /usr/local/bin/cri-dockerd

    # Create systemd service and socket files for cri-dockerd
    cat <<EOF | tee /etc/systemd/system/cri-docker.service
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.9
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    cat <<EOF | tee /etc/systemd/system/cri-docker.socket
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service

[Socket]
ListenStream=/var/run/cri-dockerd.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

    systemctl daemon-reload
    systemctl enable cri-docker
    systemctl start cri-docker
    systemctl is-active cri-docker

    # 3. Add Kubernetes AliCloud yum source
    cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
EOF
    dnf makecache
    dnf install -y kubelet-$K8S_VERSION kubeadm-$K8S_VERSION kubectl-$K8S_VERSION --disableexcludes=kubernetes
    systemctl enable kubelet

    # 4. Set kubelet connect with cri-dockerd
    cat <<EOF | tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--container-runtime=remote --container-runtime-endpoint=unix:///var/run/cri-dockerd.sock"
EOF

    # 5. Role judgment and cluster initialization/join
    ROLE=${instance_role}
    MASTER_IP=${instance_master_ip}
    JOIN_CMD_FILE="/root/join_command.sh"
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    if [[ "$ROLE" == "master" ]]; then
        echo ">>> Start to configure Kubernetes Master node"

        # Pull required images first to speed up the initialization process
        kubeadm config images pull \
            --image-repository=registry.aliyuncs.com/google_containers \
            --kubernetes-version=v$K8S_VERSION \
            --cri-socket=unix:///var/run/cri-dockerd.sock

        # Generate kubeadm configuration file with IPVS mode for kube-proxy
        cat <<EOF > /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $LOCAL_IP
nodeRegistration:
  name: ${instance_name}
  criSocket: unix:///var/run/cri-dockerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v$K8S_VERSION
imageRepository: registry.aliyuncs.com/google_containers
networking:
  podSubnet: $K8S_CIDR
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
EOF

        # Initialize cluster with IPVS-enabled kube-proxy
        kubeadm init --config=/root/kubeadm-config.yaml

        mkdir -p $HOME/.kube
        cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config

        # Generate join command (note the --cri-socket parameter)
        kubeadm token create --print-join-command | sed 's|$| --cri-socket=unix:///var/run/cri-dockerd.sock|' > $JOIN_CMD_FILE

        # Install Calico
        kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.4/manifests/tigera-operator.yaml
        cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 192.168.0.0/16
      encapsulation: VXLAN
      natOutgoing: Enabled
      nodeSelector: all()
EOF
        echo "Master node initialized, join command generated: $JOIN_CMD_FILE"
        
        # Wait a bit for the cluster to stabilize
        sleep 60  
        echo ""
        echo "=== Cluster Health Summary ==="
        kubectl get node -o wide 2>/dev/null || echo "Unable to get nodes (kubectl not ready yet)"
        echo "=== Verify kube-proxy mode (should be ipvs) ==="
        kubectl get configmap -n kube-system kube-proxy -o jsonpath='{.data.config\.conf}' | grep mode || echo "Check manually"

        # Print ~/.kube/config for user reference
        echo ">>> K8s config file for kubectl access:"
        cat $HOME/.kube/config

        # Master: Install CSI driver
        if [ "${cfs_enabled}" == "true" ]; then

            if [ -n "${cfs_secret_id}" ] && [ -n "${cfs_secret_key}" ]; then
                echo ">>> Creating CFS CSI Secret in kube-system namespace"
                kubectl create secret generic ${cfs_csi_secret} \
                    -n kube-system \
                    --from-literal=TENCENTCLOUD_CFS_API_SECRET_ID="${cfs_secret_id}" \
                    --from-literal=TENCENTCLOUD_CFS_API_SECRET_KEY="${cfs_secret_key}" \
                    --dry-run=client -o yaml | kubectl apply -f -
            else
                echo "Warning: CFS_SECRET_ID or CFS_SECRET_KEY not set. CSI may fail to authenticate."
            fi

            git clone https://github.com/TencentCloud/kubernetes-csi-tencentcloud.git
            cd kubernetes-csi-tencentcloud/deploy/cfs/kubernetes/
            kubectl apply -f csi-cfs-rbac.yaml
            kubectl apply -f csi-cfs-csidriver-new.yaml
            kubectl apply -f csi-provisioner-cfsplugin-new.yaml
            kubectl apply -f csi-nodeplugin-cfsplugin-new.yaml

            echo ">>> Waiting for CFS CSI provisioner to be ready (timeout 120s)..."
            kubectl wait --for=condition=ready pod -l app=csi-provisioner-cfsplugin -n kube-system --timeout=120s || {
                echo "WARNING: CFS CSI provisioner did not become ready within 120s. Continuing anyway..."
                echo "CFS CSI provisioner health check: kubectl get pods -n kube-system | grep cfsplugin"
                
                kubectl get pods -n kube-system | grep cfsplugin || true
            }
        
            # Health check CSIDriver
            if kubectl get csidriver | grep -q "com.tencent.cloud.csi.cfs"; then
                echo ">>> CSIDriver registered successfully."
            else
                echo "WARNING: CSIDriver registration failed."
            fi
        fi

    elif [[ "$ROLE" == "node" ]]; then
        echo ">>> Start to configure Kubernetes Node node"

        if [[ ! -f "$JOIN_CMD_FILE" ]] && [[ -n "$MASTER_IP" ]]; then
            echo "Trying to copy join command from master node $MASTER_IP..."
            scp -i ${ssh_key_path} -o StrictHostKeyChecking=no root@${instance_master_ip}:/root/join_command.sh /root/
        fi

        if [[ -f "$JOIN_CMD_FILE" ]]; then
            JOIN_CMD=$(cat "$JOIN_CMD_FILE")
            $JOIN_CMD --node-name ${instance_name}
            echo "Node node has joined the cluster with name ${instance_name}"
        else
            echo "Error: Join command file $JOIN_CMD_FILE not found, and automatic retrieval failed"
            exit 1
        fi
    else
        echo "Invalid role: $ROLE, please set it to master or node"
        exit 1
    fi

    echo "=== End to Install K8s ==="
}

output() {
    echo "=== K8s CVM ${instance_name} Completed ==="
    echo "K8s Instance IP: ${instance_ip}"
    echo "K8s Instance ID: ${instance_id}"
    echo "Execute cmd to connect server: ssh -i k8s-cvm/ssh_key/cvm_key.pem root@${instance_ip}"
}

k8s_auto_completion() {
    # Enable kubectl auto-completion
    yum -y install bash-completion
    echo "source <(kubectl completion bash)" >> ~/.bashrc
    source ~/.bashrc
}

main() {
    echo "Init Rocky Linux setting ..."
    init

    if [ "${k8s_cfssl_enabled}" == "true" ]; then
        echo "CFSSL Installation flag is enabled, proceeding with installation..."
        install_cfssl
    fi

    if [ "${k8s_helm_enabled}" == "true" ]; then
        echo "Helm Installation flag is enabled, proceeding with installation..."
        install_helm
    fi

    echo "Setup K8s ..."
    setup_k8s

    echo "Enable kubectl auto-completion ..."
    k8s_auto_completion

    output
}

main