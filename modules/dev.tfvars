region = "ap-guangzhou"

# Modify your instance password
password = "MyVMPassw0rd!"

# K8s map configuration
k8s_map = {
  "master" = {
    "system_disk_type" = "CLOUD_PREMIUM",
    "system_disk_size" = 50,
    "instance_charge_type" = "SPOTPAID" # POSTPAID_BY_HOUR, SPOTPAID, PREPAID
  }
#   "node1" = {
#     "system_disk_type" = "CLOUD_PREMIUM",
#     "system_disk_size" = 50,
#     "instance_charge_type" = "POSTPAID_BY_HOUR"
#   }
}