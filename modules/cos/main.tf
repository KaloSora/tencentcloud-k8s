resource "tencentcloud_cos_bucket" "backend_config" {
  bucket = var.bucket_name   
  acl    = "private"         
  region = var.region
}