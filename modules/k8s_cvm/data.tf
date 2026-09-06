# Get availability zones
data "tencentcloud_availability_zones_by_product" "default" {
  product = "cvm"
}

# Get Ubuntu images
data "tencentcloud_images" "ubuntu" {
  image_type = ["PUBLIC_IMAGE"]
  image_name_regex = var.cvm_os_regex
}

# Get availability instance types
data "tencentcloud_instance_types" "cvm_type" {

  for_each = local.final_k8s_cluster

  # Filter instance family
  filter {
    name   = "instance-family"
    values = ["S5"]
  }

  filter {
    name   = "zone"
    values = ["${var.cvm_availability_zone}"]
  }

  cpu_core_count = each.value.cpu_core_count
  memory_size    = each.value.memory_size
}