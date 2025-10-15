module "k8s-cvm" {
  source = "./k8s-cvm"
  cpu_core_count = 4
  memory_size    = 8
  password = var.password
}