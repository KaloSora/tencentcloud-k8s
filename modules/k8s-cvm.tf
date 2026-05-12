module "k8s-cvm" {
  source = "./k8s-cvm"
  cvm_cpu_core_count = var.cvm_cpu_core_count
  cvm_memory_size    = var.cvm_memory_size
  cvm_availability_zone = var.cvm_availability_zone
  cvm_charge_type = var.cvm_charge_type
  cvm_login_user = var.cvm_login_user
  cvm_os_regex = var.cvm_os_regex
}