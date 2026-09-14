
# Tencent Cloud Self-Hosted Kubernetes

> A production-oriented self-hosted Kubernetes platform built on Tencent Cloud CVM using Terraform.

This project provides a modular Kubernetes platform on Tencent Cloud, including:

- Self-hosted Kubernetes cluster on CVM
- Terraform-based infrastructure provisioning
- Tencent Cloud CFS CSI dynamic storage
- ingress-nginx
- Prometheus, Grafana and Loki observability stack
- Kubernetes CI/CD platform
- Pod Security Standards and resource governance
- etcd backup and disaster recovery
- Automated infrastructure lifecycle management

# Table of Contents

- [Overview](#overview)
  - [Purpose](#purpose)
  - [Architecture](#architecture)

- [Infrastructure](#infrastructure)
  - [Terraform Modules](#terraform-modules)
  - [Kubernetes Cluster](#kubernetes-cluster)
  - [CFS CSI Storage](#cfs-csi-storage)
    - [CFS CSI Components](#cfs-csi-components)
    - [Architecture](#architecture-1)

- [Networking](#networking)
  - [Ingress](#ingress)

- [Security](#security)
  - [Pod Security Standards](#pod-security-standards)
  - [Pod Security Admission](#pod-security-admission)
  - [SecurityContext](#securitycontext)
  - [Ingress Security](#ingress-security)
  - [Resource Governance](#resource-governance)
    - [Resource Requests and Limits](#resource-requests-and-limits)
    - [Resource Quota](#resource-quota)
    - [Limit Range](#limit-range)

- [Observability](#observability)
  - [Prometheus](#prometheus)
  - [Grafana](#grafana)
  - [Loki](#loki)
  - [Synthetic Monitoring](#synthetic-monitoring)

- [CI/CD](#cicd)

- [Disaster Recovery](#disaster-recovery)
  - [etcd Backup & Restore](#etcd-backup--restore)
    - [Backup](#backup)
    - [Restore](#restore)

- [Deployment](#deployment)
  - [Prerequisites](#prerequisites)
  - [Terraform Runbook](#terraform-runbook)
  - [One Click Script](#one-click-script)
    - [Create](#create)
    - [Destroy](#destroy)

- [Project Structure](#project-structure)

- [Troubleshooting](#troubleshooting)
  - [Troubleshooting Workflow](#troubleshooting-workflow)
  - [Terraform Kubernetes API Connection Timeout](#terraform-kubernetes-api-connection-timeout)
    - [Symptom](#symptom)
    - [Possible Causes](#possible-causes)
    - [Troubleshooting](#troubleshooting-1)
  - [Helm Deployment Timeout](#helm-deployment-timeout)
    - [Symptom](#symptom-1)
    - [Possible Causes](#possible-causes-1)
    - [Troubleshooting](#troubleshooting-2)
  - [CFS CSI / PVC Provisioning Issues](#cfs-csi--pvc-provisioning-issues)
    - [Symptom](#symptom-2)
    - [Possible Causes](#possible-causes-2)
    - [Troubleshooting](#troubleshooting-3)

# Overview

## Purpose

The purpose of this project is to build a modular and reproducible Kubernetes platform on Tencent Cloud.

Terraform is used to provision the underlying CVM infrastructure and deploy Kubernetes platform components in a controlled and repeatable manner.

The project focuses on:

- Infrastructure as Code
- Kubernetes platform engineering
- Observability
- Security hardening
- Persistent storage
- CI/CD
- Disaster recovery
- Automated lifecycle management

## Architecture
```text
                        Tencent Cloud
                             |
              +--------------+--------------+
              |                             |
          VPC / Subnet                  COS Backend
              |
      +-------+-------+
      |               |
   Control Plane    Worker Nodes
      |               |
      +-------+-------+
              |
        Kubernetes
              |
    +---------+---------+
    |         |         |
   CFS     Ingress   Monitoring
    |         |         |
    |      nginx      |
    |              Prometheus
    |              Grafana
    |              Loki
    |
 CFS CSI
```

# Infrastructure

## Terraform Modules

The infrastructure is organized into independent Terraform modules:

| Module | Responsibility |
|---|---|
| `k8s_cvm` | Provision CVMs and bootstrap Kubernetes |
| `k8s_cfs` | Configure Tencent Cloud CFS and Kubernetes StorageClass |
| `k8s_ingress` | Deploy ingress-nginx |
| `k8s_monitoring` | Deploy Prometheus, Grafana and Loki |
| `k8s_cicd` | Deploy Kubernetes CI/CD components |

This modular structure allows individual platform components to be deployed and managed independently.

## Kubernetes Cluster

The Kubernetes cluster is deployed on Tencent Cloud CVM.

The `k8s_cvm` module is responsible for:

- CVM provisioning
- Kubernetes initialization
- Container runtime configuration
- Cluster networking
- Kubernetes bootstrap
- CFS CSI Driver installation
- kubeconfig configuration

## CFS CSI Storage

This project integrates the Tencent Cloud CFS CSI Driver to provide shared persistent storage for Kubernetes workloads.

The CFS CSI Driver implements the Kubernetes Container Storage Interface (CSI) and allows workloads running on multiple Kubernetes nodes to mount Tencent Cloud File Storage (CFS). The project uses dynamic provisioning through a Kubernetes StorageClass.

### CFS CSI Components

The CFS CSI Driver is installed as part of the Kubernetes cluster initialization process in the `k8s_cvm` module.

The `k8s_cfs` Terraform module is responsible for configuring the CFS storage resources and Kubernetes StorageClass.

The deployment consists of:

- CFS CSI controller / provisioner
- CFS CSI node plugin
- Tencent Cloud CFS access group
- CFS access rules
- Kubernetes StorageClass

The CSI components run in the kube-system namespace. The official Tencent Cloud documentation describes the controller as a StatefulSet and the node plugin as a DaemonSet.

### Architecture
```text
PVC
  ↓
StorageClass
  ↓
CFS CSI Driver
  ↓
Tencent Cloud CFS
  ↓
PV
  ↓
Pod
```

# Networking

## Ingress

The project uses ingress-nginx as the Kubernetes ingress controller.

The ingress controller is deployed as a DaemonSet on dedicated DevOps nodes.

Key configuration includes:

- Dedicated node scheduling
- `hostNetwork`
- Default IngressClass
- Health checks
- Kubernetes securityContext

# Security
## Pod Security Standards
This project applies Kubernetes Pod Security Standards (PSS) to enforce workload security and least-privilege principles.

The cluster follows the Restricted security profile where applicable, with workload-level security controls implemented through `securityContext`.

## Pod Security Admission
Pod Security Admission (PSA) is used to enforce the Pod Security Standards at the namespace level.

The three PSA modes provide different levels of enforcement:

| Mode | Purpose |
| :------- | :---: |
| enforce | Reject workloads that violate the policy |
| audit	| Record policy violations in audit information |
| warn	| Return warnings to users without rejecting the workload |

Example:
```Terraform
resource "kubernetes_namespace" "my_namespace" {
  metadata {
    name = local.my_namespace

    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}
```

## SecurityContext

Workloads are configured with:

- `runAsNonRoot`
- `allowPrivilegeEscalation: false`
- `seccompProfile: RuntimeDefault`
- `readOnlyRootFilesystem`
- Linux capabilities dropped where possible

## Ingress Security
The ingress-nginx controller is hardened using:

- `allowPrivilegeEscalation: false`
- Linux capability dropping
- RuntimeDefault seccomp profile

## Resource Governance
### Resource Requests and Limits
Implement resource limit provides workload-level resource isolation and namespace-level resource governance.

Define CPU and memory `requests` and `limits` for workloads to improve resource allocation, scheduling, and workload isolation.
- `requests` define the amount of CPU and memory requested by a workload and are used by the Kubernetes scheduler for resource placement.
- `limits` define the maximum amount of CPU and memory that a container can consume.
- Resource limits help prevent individual workloads from consuming excessive resources and affecting other workloads.

For example:
```YAML
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: "2"
      memory: 2Gi
```

### Resource Quota
ResourceQuota defines the maximum aggregate resources that can be requested by a namespace. It does not pre-allocate or reserve the configured resources.
Resource limits and quotas provide two levels of resource governance:

For example:
```Terraform
resource "kubernetes_resource_quota" "ingress_nginx_quota" {
  metadata {
    name      = "ingress-nginx-quota"
    namespace = kubernetes_namespace.ingress_nginx_namespace.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "1"
      "requests.memory" = "512Mi"
      "limits.cpu"      = "2"
      "limits.memory"   = "2Gi"
      "pods" = "10"
    }
  }
}
```

### Limit Range
Not all container will set resource.
Use resource `kubernetes_limit_range` to set default resource limit to avoid `resource {}`.

# Observability

The monitoring stack provides metrics, dashboards and centralized logging for the Kubernetes platform.

## Prometheus

Prometheus is used for:

- Kubernetes metrics
- Node metrics
- Application metrics
- Alerting
- Service monitoring

## Grafana

Grafana provides visualization and dashboards for:

- Kubernetes cluster
- Nodes
- Pods
- Prometheus metrics
- Loki logs

## Loki

Loki provides centralized log aggregation.

Promtail collects container logs from Kubernetes nodes and forwards them to Loki.

## Synthetic Monitoring

Planned feature.

Synthetic monitoring will be used to continuously verify the availability and response time of critical application endpoints.

# CI/CD

The project provides a Kubernetes-based CI/CD platform for application build, image management and deployment automation.

The CI/CD stack includes:

- Jenkins
- GitLab
- Harbor
- Argo CD

Workflow
```text
Developer
    |
    v
GitLab
    |
    v
Jenkins
    |
    v
Build
    |
    v
Harbor
    |
    v
Argo CD
    |
    v
Kubernetes
```

# Disaster Recovery

## etcd Backup & Restore

The Kubernetes control plane uses etcd as the cluster state store.

The project provides an etcd backup and restore strategy to protect critical Kubernetes control-plane data.

### Backup

```text
Kubernetes API Server
        |
        v
       etcd
        |
        v
   etcd snapshot
        |
        v
 Tencent Cloud COS
```

### Restore

```text
COS Backup
    |
    v
etcd snapshot
    |
    v
etcd restore
    |
    v
Kubernetes API Server
```


# Deployment

## Prerequisites
Execute below command
1. Install tencent cloud cli and input secret key/id
```bash
# Make sure python3 installed on your PC
sudo pip install tccli
tccli --version
tccli configure

# Install cos command line
pip install coscmd
coscmd mb cos://cvm-k8s-config
```
Secret id and secret key will be stored to `~/.tccli/default.credential`

coscmd config will be stored at `/Users/YOUUSERNAME/.cos.conf`

Tencent cloud cli user guide can refer to [Tencent Cloud cli](https://cloud.tencent.com/document/product/440/34012)

2. Create cos backend bucket via tencent cloud cli
```bash
coscmd config -a <secreate_id> -s <secret_key> -r <region> -b <bucket>
coscmd -b cvm-k8s-config-<APPID> -r gz createbucket

# For example
coscmd -b cvm-k8s-config-1304007562 -r gz createbucket
```
By installing the tencent cloud sdk, we can create the backend bucket before terraform init.

If any `403` error, please refer to [Tencent Cloud troubleshoot](https://cloud.tencent.com/document/product/436/54303)

3. Terraform init
```bash
export TF_VAR_secret_id="YOU_SECRET_ID"
export TF_VAR_secret_key="YOU_SECRET_KEY"
cd modules
terraform init -backend-config="bucket=cvm-k8s-config-1304007562" -backend-config="region=ap-guangzhou" -backend-config="secret_id=${TF_VAR_secret_id}" -backend-config="secret_key=${TF_VAR_secret_key}"
```
For tencent cloud oss backend, must provide the secret id and secret key, otherwise it will return 403 Access Denied error.

4. Create vm on tencent cloud
```bash
terraform plan -target=module.k8s_cvm -var-file="./dev.tfvars"
terraform apply -target=module.k8s_cvm -var-file="./dev.tfvars"

# To destroy 
terraform destroy -target=module.k8s_cvm -var-file="./dev.tfvars"
```

5. SSH to server to perform health check
```bash
ssh USERNAME@YOURIP

kubectl get ns
```

## Terraform Runbook

| Step | Command | Description |
| :--- | :--- | :--- |
| 1 | `terraform init ...` | Initialize Terraform backend |
| 2 | `terraform apply ...` | Deploy Kubernetes on CVM |
| 3 | `terraform apply ...` | Configure CFS CSI storage |
| 4 | `terraform apply ...` | Deploy ingress-nginx |
| 5 | `terraform apply ...` | Deploy monitoring stack |
| 6 | `terraform apply ...` | Deploy CI/CD platform |

## One Click Script
### Create
```bash
./script/create.sh
```

### Destroy
```bash
./script/destroy.sh
```

# Project Structure

```text
.
├── modules/
│   ├── k8s_cvm/
│   ├── k8s_cfs/
│   ├── k8s_ingress/
│   ├── k8s_monitoring/
│   └── k8s_cicd/
│
├── script/
│   ├── create.sh
│   └── destroy.sh
│
├── config/
│   ├── monitoring/
│   └── ...
│
├── dev.tfvars
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

# Troubleshooting

This section documents common issues encountered during the deployment and operation of the Kubernetes platform.

## Troubleshooting Workflow

For most Kubernetes issues, follow a consistent troubleshooting workflow:

```text
1. Check Pod Status
        |
        v
2. Check Events
        |
        v
3. Check Pod Logs
        |
        v
4. Check Service / Endpoints
        |
        v
5. Check Storage
        |
        v
6. Check Node Resources
        |
        v
7. Check Network / Ingress
        |
        v
8. Check Terraform / Helm Configuration
```

Useful commands:
```bash
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl get svc -A
kubectl get ingress -A
kubectl get pvc -A
kubectl get nodes
kubectl top nodes
```

## Terraform Kubernetes API Connection Timeout
### Symptom

Terraform fails to connect to the Kubernetes API server:

dial tcp <API_SERVER>:6443: i/o timeout

### Possible Causes
- Kubernetes API server is not ready yet
- The local kubeconfig points to an unavailable API endpoint
- The Kubernetes cluster is still being initialized
- Terraform starts Kubernetes resources before the control plane is ready

### Troubleshooting

Check the cluster from the master node:
```bash
kubectl get nodes
kubectl get pods -A

kubectl cluster-info
```

Although the cluster works fine, k8s provider fail to create resources in the same module.

Move the k8s resource to another module to avoid terraform lifecycle error.

## Helm Deployment Timeout
### Symptom

Terraform Helm deployment fails with:

context deadline exceeded

### Possible Causes
- Kubernetes workloads are still starting
- Container images are being pulled
- PersistentVolumeClaims are waiting for storage
- Pods cannot be scheduled
- Helm timeout is too short
- Troubleshooting

Check Helm releases:

```bash
helm list -A
```

Check pods:

```bash
kubectl get pods -A
```

Check pending pods:
```bash
kubectl get pods -A | grep Pending
```

Inspect pod events:

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs pod <pod-name> -n <namespace>
```

For large monitoring workloads, increase the Helm timeout when necessary.

## CFS CSI / PVC Provisioning Issues
### Symptom

CSI provider fail to revoke PV even if the pod has been deleted.
A PVC remains in Pending state:

```text
NAME          STATUS    VOLUME   CAPACITY
example-pvc   Pending
```

### Possible Causes
- CFS CSI Driver is not running
- StorageClass configuration is incorrect
- CFS access group or access rules are incorrect
- Kubernetes nodes cannot reach the CFS service
- PVC requests an unsupported configuration

### Troubleshooting

Check the PVC:

```bash
kubectl describe pvc <pvc-name>
```

Check the StorageClass:
```bash
kubectl get storageclass
kubectl describe storageclass cfs-shared-storageclass
```
Check the CSI driver:
```bash
kubectl get csidriver
```
Check CFS CSI components:
```bash
kubectl get pods -n kube-system | grep cfs
```
Check Kubernetes events:
```bash
kubectl get events -A --sort-by=.lastTimestamp
```
