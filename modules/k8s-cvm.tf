module "k8s-cvm" {
  source = "./k8s-cvm"
  k8s_map = var.k8s_map
  cpu_core_count = 4
  memory_size    = 8
  password = var.password
}