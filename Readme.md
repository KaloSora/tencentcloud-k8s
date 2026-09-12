# Purpose
This repository mainly use terraform to create vm and deploy k8s on tencent cloud.

# Feature
## Pod Security Standard
This project applies Kubernetes Pod Security Standards (PSS) to enforce workload security and least-privilege principles.

The cluster follows the Restricted security profile where applicable, with workload-level security controls implemented through `securityContext`.

### Security Controls
The following security controls are applied to Kubernetes workloads:
- Run containers as a non-root user
- Disable privilege escalation
- Drop unnecessary Linux capabilities
- Use the default RuntimeDefault seccomp profile
- Use a read-only root filesystem where supported
- Minimize container privileges according to the workload requirements

Example:
```YAML
securityContext: 
    runAsNonRoot: true 
    runAsUser: 1000 
    runAsGroup: 1000 
    seccompProfile: 
        type: RuntimeDefault 

containers: 
    - name: application 
    securityContext: allow
    PrivilegeEscalation: false 
    readOnlyRootFilesystem: true 
        capabilities: 
        drop: - ALL
```

### Pod Security Admission
Pod Security Admission (PSA) is used to enforce the Pod Security Standards at the namespace level.

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

The three PSA modes provide different levels of enforcement:

| Mode | Purpose |
| :------- | :---: |
| enforce | Reject workloads that violate the policy |
| audit	| Record policy violations in audit information |
| warn	| Return warnings to users without rejecting the workload |

### Ingress Security
The ingress-nginx controller runs as a DaemonSet on dedicated DevOps nodes using hostNetwork for direct node-level traffic handling.

The controller is hardened using:
- Set `allowPrivilegeEscalation: false`: to restrict the ability of a process to gain more privileges than its parent process
- Linux capability dropping: to drop all capabilities(like CAP_NET_ADMIN, CAP_SYS_ADMIN, CAP_SYS_PTRACE ... etc.) and only allow the ones that are explicitly added
- Security Computing: to use the default seccomp profile for the container runtime to avoid dangerous syscall

## Resource Limit
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

It provides both workload-level resource isolation and namespace-level resource governance.

# Prerequisites
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

# Terraform Runbook
| Step     | Command | Description  |
| :------- | :---: | ----: |
| 1     | terraform init -backend-config="YOUR_BUCKET" | To deploy K8s on CVM  |
| 2     | terraform apply -target=module.k8s_cvm -var-file="dev.tfvars"   | To deploy K8s on CVM |
| 3     | terraform apply -target=module.k8s_cfs -var-file="dev.tfvars"   | To create K8s storage with CFS CSI |
| 4     | terraform apply -target=module.k8s_ingress -var-file="dev.tfvars"   | To deploy ingress-nginx on K8s cluster  |
| 5     | terraform apply -target=module.k8s_monitoring -var-file="dev.tfvars"   | To deploy monitoring framework on K8s cluster  |
| 6     | terraform apply -target=module.k8s_cicd -var-file="dev.tfvars"   | To deploy K8s CICD on K8s cluster  |

# One Click Script
```bash
# To create the whole infrastructure
./script/create.sh

# To destroy the whole infrastructure
./script/destroy.sh
```