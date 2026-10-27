
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
| `k8s_app` | Create secured application namespaces for environment promotion |

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

Planned feature, under development.

The project provides a Kubernetes-based CI/CD platform for application build, image management and deployment automation.

The CI/CD stack includes:

- Jenkins
- GitHub
- Harbor
- Argo CD

Jenkins is initialized through Configuration as Code. Its controller has no
local executors; builds run as disposable Pods in the `cicd-build` namespace
using the least-privilege `jenkins-agent` ServiceAccount. The pipeline job reads
its Jenkinsfile from the repository configured under
`cicd_components.jenkins.config`.

GitOps promotion credentials can also be provisioned through Terraform and
JCasC. Export these variables in the shell that runs Terraform from `modules/`:

```bash
export TF_VAR_gitops_credentials_id='gitops-github-token'
# Prompt without echoing the token or putting it in shell history (bash/zsh).
printf 'GitHub token: '
read -r -s TF_VAR_gitops_github_token
printf '\n'
export TF_VAR_gitops_github_token
```

Use the `TF_VAR_` prefix, not `TF_VARS_`. The ID defaults to
`gitops-github-token`; the token is required and must be nonempty with no
whitespace. Both the root and child module reject empty or null tokens, even
when Jenkins is disabled. `modules/dev.tfvars` declares both settings, with an
empty token placeholder that must be overridden before planning. When using
`-var-file=dev.tfvars`, that placeholder overrides `TF_VAR_gitops_github_token`.
Supply the real token through a private variable file loaded afterward, for
example `terraform plan -var-file=dev.tfvars -var-file=/private/path/gitops.tfvars`.
Keep that private file outside the repository and never commit the real token
in `dev.tfvars`. The root module passes these inputs to `module.k8s_cicd`.
With Jenkins enabled, Terraform creates `jenkins-gitops-github-token` in the Jenkins
controller namespace. Helm injects it into the controller using `secretKeyRef`,
and JCasC creates a **Secret text** credential under the selected ID. The token
is not embedded in Helm values or JCasC ConfigMaps. JCasC publishes only the ID
as `JENKINS_GITOPS_CREDENTIALS_ID`, which the application promotion Jenkinsfile
uses with `withCredentials`. Update `ci/jenkins/Jenkinsfile.promotion` on the
branch configured for the promotion job to pick up custom IDs.

Supply the token on every plan/apply; exporting only an ID is insufficient.
Changing IDs can leave the old Jenkins credential behind; review and remove
obsolete credentials manually.

The token is sensitive but **is stored in Terraform state and saved plans**;
protect both and never commit them. Use a repository-scoped GitHub token with
the permissions needed by promotion: read the application repository and read/
write GitOps contents and pull requests. Review a Terraform plan before an
approved apply. Initial configuration and token rotation restart the controller
to refresh its environment; the PVC is retained. Rotation requires a restart
even if JCasC auto-reload is enabled. This configuration does not apply changes
to the running cluster until the reviewed Terraform deployment is executed.

If a build obtains its Jenkinsfile but immediately reports `Start of Pipeline`,
`End of Pipeline`, and `SUCCESS` without any stages, inspect controller plugin
loading before investigating Maven or agent scheduling:

```bash
kubectl --kubeconfig modules/kubeconfig/config logs -n jenkins jenkins-0 -c jenkins \
  | rg -A 8 'Failed Loading plugin|Failed to load|Update required'
```

An observed failure combined Declarative extensions `2.2277.v00573e73ddf1`
with Model API `2.2218.v56d0cda_37c72`, Workflow Job `1472.ve4d5eca_143c4`,
and Stage Step `312.v8cd10304c27a_`. This prevented Declarative and the Pipeline
aggregator from loading even though Jenkins was ready and could create jobs.
`jenkins-controller.yaml` pins a compatible Declarative family and its required
Job/Stage versions, and explicitly installs Timestamper for `timestamps()`.
`overwritePlugins: true` reconciles plugin files on the persistent home during
controller initialization; JCasC reload alone cannot repair plugin loading.
The chart clears the plugin directory and repopulates it from the resolved list;
plugins installed only through the UI must first be declared in Helm values.
Review plugin changes and back up Jenkins home before an approved Helm/Terraform
upgrade. The controller restarts; its PVC and build history are retained.

After the upgrade, confirm there are no plugin-loading failures and rerun the
branch build. Expect `Checkout`, `Maven Package`, and `Kaniko Build and Push`
stages; this rerun publishes an image to Harbor. Earlier empty successful builds
remain in the history and do not contain application build artifacts.

When both Jenkins and Harbor are enabled, Terraform creates a restricted
`jenkins-harbor-bootstrap` ServiceAccount, namespaced RBAC, script ConfigMap,
and a one-shot Job in the Harbor namespace. The Job runs after the Harbor Helm
release is ready and Terraform waits for it to complete. It reads the existing
Harbor admin Secret inside the cluster, creates a project robot with repository
pull/push permissions, verifies a registry token, and writes
`cicd-build/harbor-docker-config`. The generated robot password is never returned
to Terraform, written to a workstation file, or printed in Job logs. The Job
uses the existing Python runtime image pattern and requires no Harbor Terraform
provider or workstation access to the Harbor Ingress.

A valid existing Secret is verified and retained. Ordinary applies do not rotate
passwords or recreate the completed Job. On a full `terraform destroy`, the
build namespace removes the Secret; the Harbor chart's `resourcePolicy: delete`
removes its PVCs, including the database that stores the robot. A fresh apply
creates a new robot and Secret automatically. Retaining or restoring Harbor
storage changes this assumption: the bootstrap can provision new credentials,
but old robot accounts in retained Harbor data require separate cleanup.
This design targets the full-stack create/destroy workflow, not standalone
lifecycle management of robot accounts in an external Harbor instance.

Application image pulls are also managed by Terraform. After Ingress exists,
`module.k8s_cicd` configures each Docker node's Harbor hostname and HTTP registry
access, then installs the `harbor-app-pull` chart to verify/create pull-only
Secrets in the application namespaces and renew expiring credentials daily.
See [Terraform-managed Harbor access](modules/k8s_cicd/HARBOR_ACCESS.md) for
rebuild behavior, lifecycle boundaries and verification commands.

Optional non-secret Jenkins component config keys are
`jenkins_harbor_project` (default `library`),
`jenkins_harbor_robot_duration_days` (default `90`), and
`jenkins_harbor_bootstrap_revision` (default `1`). Use the configured project as
the Jenkins `HARBOR_PROJECT` build parameter. A long-lived environment must
rerun bootstrap before robot expiry: increment the revision and apply; the new
Job retains valid credentials or renews credentials expiring within one day.
The Secret annotations record the robot ID and expiry timestamp. The completed
Job has no TTL so Kubernetes garbage collection does not cause credential work
on every apply. Its name includes a script/config hash so a bootstrap change
creates a new Job.

Inspect bootstrap logs if the build agent is waiting for the registry Secret:

```bash
kubectl --kubeconfig modules/kubeconfig/config get jobs -n harbor
kubectl --kubeconfig modules/kubeconfig/config logs -n harbor job/<bootstrap-job-name>
```

Harbor also needs DNS inside the cluster. `k8s_cicd/cluster_dns.tf` manages
the existing kubeadm CoreDNS ConfigMap's `Corefile` field. It preserves other
resolver settings and replaces a marked CI/CD block idempotently. When Harbor
is enabled, its configured `harbor_url` resolves to
`ingress-nginx-controller.ingress-nginx.svc.cluster.local` through an exact
CoreDNS rewrite. The module input `ingress_controller_service_fqdn` overrides
that Service name if the Ingress installation changes. No Service or node IP
is hardcoded. Requests retain the Harbor hostname for Ingress routing and robot
authentication, and travel over the cluster's internal network.

The DNS resource is a dependency of the component Helm releases, so both normal
applies and `script/create.sh`'s targeted CI/CD step install it on fresh clusters.
CoreDNS uses its existing `reload` plugin; allow time for reload and DNS caches
to expire before retrying a failed build. A custom Corefile without kubeadm's
default `.:53` block requires review before applying. Changes to other CoreDNS
settings should be made before planning so this resource can preserve them.
This configures Pod DNS only; workstation and node/container-runtime DNS must
be configured separately if they also access this private Harbor hostname.

To verify from a Pod, resolve `harbor.core.com` and request
`http://harbor.core.com/v2/`. An unauthenticated `401` with a Harbor Bearer
challenge confirms DNS and Ingress routing; it does not by itself prove push
permission. Keep `harbor.core.com` as the registry hostname in image references
and in the Docker Secret. A workstation `/etc/hosts` entry is not inherited by
build Pods.

The former local credentials input and Secret import block are no longer used.
No credential file is needed for a fresh cluster. Existing admin passwords and
other Helm values continue to follow the platform's configuration and encrypted
COS Terraform backend; the in-cluster handling above specifically keeps the
Jenkins robot password out of local files and Terraform state. This change does
not resolve the application agent's separate non-root container configuration.

Crossplane installation and the separate infrastructure GitOps bootstrap are documented in
[`modules/k8s_cicd/CROSSPLANE.md`](modules/k8s_cicd/CROSSPLANE.md).

CI/CD Helm releases are created by the reusable `helm_component` module. Each
entry in `cicd_components` defines its namespace, chart, version, values
templates, lifecycle flags, and component-specific configuration. A regular
new component therefore requires an inventory entry and a values YAML template,
not another copy of the `helm_release` resource.

Workflow
```text
Developer
    |
    v
GitHub
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
Use `terraform apply -target=<module> -var-file="dev.tfvars"` to use Terraform variables

| Step | Command | Description |
| :--- | :--- | :--- |
| 1 | `terraform init -backend-config="YOUR_BUCKET"` | Initialize Terraform backend |
| 2 | `terraform apply -target=module.k8s_cvm` | Deploy Kubernetes on CVM |
| 3 | `terraform apply -target=module.k8s_cfs` | Configure CFS CSI storage |
| 4 | `terraform apply -target=module.k8s_ingress` | Deploy ingress-nginx |
| 5 | `terraform apply -target=module.k8s_monitoring` | Deploy monitoring stack |
| 6 | `terraform apply -target=module.k8s_app` | Create application promotion namespaces |
| 7 | `terraform apply -target=module.k8s_cicd` | Deploy CI/CD platform, node registry access and application pull credentials |

## One Click Script
### Create
```bash
./script/create.sh
```

The create script currently skips monitoring to shorten temporary cluster creation;
CI/CD remains enabled by default. Set `DEPLOY_MONITORING=true` to include monitoring.
Grafana is provided
by kube-prometheus-stack alongside the existing Prometheus/Loki monitoring
configuration. Set `DEPLOY_MONITORING=false` or `DEPLOY_CICD=false` in the
environment to skip the corresponding step. Python 3 is required to decode
Terraform console string values, including escaped password characters.

For this create/verify/destroy environment, the final access summary prints the
configured Grafana, Jenkins, Argo CD, Harbor and enabled Plane login passwords
in plaintext, as explicitly requested. Values come from `dev.tfvars` through
Terraform console; no passwords are embedded in the script. This summary shows
configured initial credentials, so retained volumes or manual password changes
can cause a running service's credentials to differ.

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
│   ├── k8s_cicd/
│   └── k8s_app/
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
