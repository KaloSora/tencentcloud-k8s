apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STORAGE_CLASS_NAME}
provisioner: com.tencent.cloud.csi.cfs
reclaimPolicy: Delete # Retain / Delete
volumeBindingMode: Immediate
mountOptions:
  - vers=3
  - nolock
  - proto=tcp
  - noresvport
parameters:
  vpcId: ${VPC_ID}
  subnetId: ${SUBNET_ID}
  storageType: SD
  pgroupid: ${CFS_PGROUP_ID}
