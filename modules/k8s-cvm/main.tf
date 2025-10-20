locals {
  login_user = "ubuntu"
  script_template = "${path.module}/template/k8s_init.sh.tpl"
  script_remote = "/tmp/k8s_init.sh"
}

# Get availability zones
data "tencentcloud_availability_zones_by_product" "default" {
  product = "cvm"
}

# Get Ubuntu images
data "tencentcloud_images" "default" {
  image_type = ["PUBLIC_IMAGE"]
  os_name    = "ubuntu"
}

# Get availability instance types
data "tencentcloud_instance_types" "default" {
  # Filter instance family
  filter {
    name   = "instance-family"
    values = ["S5"]
  }

  cpu_core_count = var.cpu_core_count
  memory_size    = var.memory_size
}

# Create a web server
resource "tencentcloud_instance" "web" {
  for_each                   = var.k8s_map
  depends_on                 = [tencentcloud_security_group_lite_rule.default]
  instance_name              = "k8s-${each.key}"
  availability_zone          = data.tencentcloud_availability_zones_by_product.default.zones.0.name
  image_id                   = data.tencentcloud_images.default.images.0.image_id
  instance_type              = data.tencentcloud_instance_types.default.instance_types.0.instance_type
  system_disk_type           = each.value.system_disk_type
  system_disk_size           = each.value.system_disk_size
  allocate_public_ip         = true
  internet_max_bandwidth_out = 100
  instance_charge_type       = each.value.instance_charge_type
  orderly_security_groups    = [tencentcloud_security_group.default.id]
  password                   = var.password

  # Add local-exec to echo instance ip, id and password on console
#   provisioner "local-exec" {
#     command = <<EOT
# echo "================= K8s Instance Info ================="
# echo "K8s instance IP: ${tencentcloud_instance.web[0].public_ip}"
# echo "K8s instance ID: ${tencentcloud_instance.web[0].id}"
# echo "K8s instance login username: ${local.login_user} - Using ubuntu as image"
# echo "K8s instance login password: ${var.password}"
# echo "K8s ${each.key} server created."
# echo "====================================================="
# EOT
#   }
}

# Create security group
resource "tencentcloud_security_group" "default" {
  name        = "tf-security-group"
  description = "make it accessible for both production and stage ports"
}

# Create security group rule allow ssh request
resource "tencentcloud_security_group_lite_rule" "default" {
  security_group_id = tencentcloud_security_group.default.id
  ingress = [
    "ACCEPT#0.0.0.0/0#22#TCP",
    "ACCEPT#0.0.0.0/0#6443#TCP",
  ]

  egress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL"
  ]
}

# Connect to cvm to install k8s
# resource "null_resource" "connect_cvm" {
#   depends_on = [tencentcloud_instance.web]

#   # Define cvm connection
#   connection {
#     host     = tencentcloud_instance.web[0].public_ip
#     type     = "ssh"
#     user     = local.login_user
#     password = var.password
#   }

#   # Only when template file changed, it will re-run the provisioner
#   triggers = {
#     script_hash = filemd5("${local.script_template}")
#   }

#   # Upload local file template to cvm
#   provisioner "file" {
#     destination = "${local.script_remote}"
#     content = templatefile(
#       "${local.script_template}",
#       {
#         "public_ip" : "${tencentcloud_instance.web[0].public_ip}"
#       }
#     )
#   }

#   # Execute script on remote cvm
#   provisioner "remote-exec" {

#     inline = [
#       "chmod +x ${local.script_remote}",
#       "sh ${local.script_remote}",
#     ]
#   }
# }