module "cos" {
  source = "./cos"
  bucket_name = "cvm-k8s-config"
  region = var.region
}