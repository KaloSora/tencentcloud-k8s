locals {
  cvm_key_name = "cvm_ssh_key"
  cvm_key_filename = "${path.module}/ssh_key/cvm_key.pem"
  cvm_key_filename_pub = "${path.module}/ssh_key/cvm_key.pub"

  init_script = "init.sh"
  init_script_tpl = "init.sh.tpl"
}

# Create local ssh key pair
# Important: Do not commit the private key to Github
resource "tls_private_key" "cvm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "cvm_private_key" {
  content  = tls_private_key.cvm_key.private_key_pem
  filename = local.cvm_key_filename
  
  provisioner "local-exec" {
    command = "chmod 600 ${local.cvm_key_filename}"
  }
}

# Upload keypair to tencent cloud
resource "tencentcloud_key_pair" "cvm-key" {
  key_name   = local.cvm_key_name
  public_key = tls_private_key.cvm_key.public_key_openssh
}


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

  for_each = var.k8s_cluster

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

# Create a k3s server
resource "tencentcloud_instance" "k3s_server" {

  for_each = var.k8s_cluster

  depends_on                 = [tencentcloud_security_group_lite_rule.default]
  instance_name              = "${each.value.instance_name}"
  availability_zone          = data.tencentcloud_availability_zones_by_product.default.zones.0.name
  image_id                   = data.tencentcloud_images.ubuntu.images.0.image_id
  instance_type              = data.tencentcloud_instance_types.cvm_type[each.key].instance_types.0.instance_type
  system_disk_type           = "CLOUD_PREMIUM"
  system_disk_size           = 100
  allocate_public_ip         = true
  internet_max_bandwidth_out = 100
  instance_charge_type       = var.cvm_charge_type
  orderly_security_groups    = [tencentcloud_security_group.default.id]

  key_ids                    = [tencentcloud_key_pair.cvm-key.id]

  tags = {
    Name = each.value.instance_name
    Role = each.key
    CPU  = tostring(each.value.cpu_core_count)
    Mem  = tostring(each.value.memory_size)
  }
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


# Setup the CVM
resource "null_resource" "ssh_connection" {

  for_each = tencentcloud_instance.k3s_server  

  depends_on = [tencentcloud_instance.k3s_server]
  
  # Condition: once script changed, this module will re-run
  triggers = {
    script_hash = filemd5("${path.module}/script/${local.init_script_tpl}")
    instance_id = each.value.id
  }

  connection {
    type        = "ssh"
    host        = each.value.public_ip
    user        = var.cvm_login_user
    #password    = var.password
    private_key = tls_private_key.cvm_key.private_key_pem
    port        = 22
    timeout     = "2m"
  }

  # Local script upload with terraform template file
  provisioner "file" {
    destination = "/tmp/${local.init_script}"
    content = templatefile(
      "${path.module}/script/${local.init_script_tpl}",
      {
        "instance_ip" : "${each.value.public_ip}"
        "instance_id" : "${each.value.id}"
        "target_user" : "${var.cvm_login_user}"
      }
    )
  }

  # Remote-exec provisioner to run commands on the CVM instance via SSH
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/${local.init_script}",

      "echo 'Start execute init script ...'",
      "ls -la /tmp/${local.init_script}",

      # Run the setup script
      "sudo sh /tmp/${local.init_script}",
      "echo 'Execution completed!'"
    ]
  }
}