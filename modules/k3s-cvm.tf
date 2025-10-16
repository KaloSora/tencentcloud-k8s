module "k3s-cvm" {
  source = "./k3s-cvm"
  cpu_core_count = 4
  memory_size    = 8
  password = var.password
}