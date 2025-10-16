# Purpose
This repository mainly use terraform to create vm and deploy k8s on tencent cloud.

# Usage
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
terraform plan -target=module.k8s-cvm -var-file="./dev.tfvars"
terraform apply -target=module.k8s-cvm -var-file="./dev.tfvars"

# To destroy 
terraform destroy -target=module.k8s-cvm -var-file="./dev.tfvars"
```

If you need to modify instance login password, check vars file `dev.tfvars`

### K3s Install
**If you just want a quick and simple k8s environment, can execute below module**

It will only create 1 cvm and install k3s
``` bash
terraform plan -target=module.k3s-cvm -var-file="./dev.tfvars"
terraform apply -target=module.k3s-cvm -var-file="./dev.tfvars"

# To destroy
terraform destroy -target=module.k3s-cvm -var-file="./dev.tfvars"
```

Here is difference between k8s and k3s
|       | Kubernetes (K8s)       | K3s       |
|-----------|-----------|-----------|
| Design    | Full-featured enterprise-grade   | Lightweight, edge and IoT-focused    |
| Resources | High resource demands    | Optimized for low-resource environments    |
| Components      | Multi-component, uses etcd    | Single binary, SQLite default (etcd optional)    |
| Installation    | Complex setup    | Simple, single-binary installation    |
| Use cases       | Large-scale production    | Edge, IoT, local dev, and small clusters    |
| Security        | Advanced, multi-tenant    | Basic, single-tenant; manual hardening needed    |
| Performance     | High scalability for extensive workloads    | Efficient in limited environments, faster setup    |
| Community support    | Strong, with a vast community and tooling    | Growing community, more limited tooling    |


5. SSH to server to perform health check
```bash
ssh USERNAME@YOURIP

kubectl get ns
```