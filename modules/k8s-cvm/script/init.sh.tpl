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

    # Load kernel modules
    cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter

    # Configure sysctl
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sysctl --system
}

setup_k8s() {
    set -e
    echo "=== Start to Install K8s ==="

    K8S_VERSION="1.28.8"

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
    CRI_DOCKERD_VERSION="0.3.15"
    wget https://github.com/Mirantis/cri-dockerd/releases/download/v$CRI_DOCKERD_VERSION/cri-dockerd-$CRI_DOCKERD_VERSION.amd64.tgz
    tar -xzf cri-dockerd-$CRI_DOCKERD_VERSION.amd64.tgz
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

    if [[ "$ROLE" == "master" ]]; then
        echo ">>> Start to configure Kubernetes Master node"

        # Pull required images first to speed up the initialization process
        kubeadm config images pull \
            --image-repository=registry.aliyuncs.com/google_containers \
            --kubernetes-version=v$K8S_VERSION \
            --cri-socket=unix:///var/run/cri-dockerd.sock

        kubeadm init \
            --image-repository=registry.aliyuncs.com/google_containers \
            --pod-network-cidr=192.168.0.0/16 \
            --apiserver-advertise-address=$(hostname -I | awk '{print $1}') \
            --kubernetes-version=v$K8S_VERSION \
            --cri-socket=unix:///var/run/cri-dockerd.sock

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
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF
        echo "Master node initialized, join command generated: $JOIN_CMD_FILE"

        if [[ "$ROLE" == "master" ]]; then
            sleep 30  # Wait a bit for the cluster to stabilize
            echo ""
            echo "=== Cluster Health Summary ==="
            kubectl get node -o wide 2>/dev/null || echo "Unable to get nodes (kubectl not ready yet)"
        fi

    elif [[ "$ROLE" == "node" ]]; then
        echo ">>> Start to configure Kubernetes Node node"

        if [[ ! -f "$JOIN_CMD_FILE" ]] && [[ -n "$MASTER_IP" ]]; then
            echo "Trying to copy join command from master node $MASTER_IP..."
            scp -i ${ssh_key_path} root@${instance_master_ip}:/root/join_command.sh /root/
        fi

        if [[ -f "$JOIN_CMD_FILE" ]]; then
            bash $JOIN_CMD_FILE
            echo "Node node has joined the cluster"
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

main() {
    echo "Init Rocky Linux setting ..."
    init

    echo "Setup K8s ..."
    setup_k8s

    output
}

main