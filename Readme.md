# Purpose
This repository mainly use terraform to create vm and deploy k8s on tencent cloud.

# Usage
Execute below command
1. Terraform init
```bash
cd modules
terraform init
```

2. Create vm on tencent cloud
```bash
terraform apply -target=module.cvm -var-file="./dev.tfvars"
```

If you need to modify instance login password, check vars file `dev.tfvars`