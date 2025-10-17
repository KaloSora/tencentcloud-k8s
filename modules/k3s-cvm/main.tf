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
  depends_on                 = [tencentcloud_security_group_lite_rule.default]
  count                      = 1
  instance_name              = "web server"
  availability_zone          = data.tencentcloud_availability_zones_by_product.default.zones.0.name
  image_id                   = data.tencentcloud_images.default.images.0.image_id
  instance_type              = data.tencentcloud_instance_types.default.instance_types.0.instance_type
  system_disk_type           = "CLOUD_PREMIUM"
  system_disk_size           = 50
  allocate_public_ip         = true
  internet_max_bandwidth_out = 100
  instance_charge_type       = "SPOTPAID"
  orderly_security_groups    = [tencentcloud_security_group.default.id]
  password                   = var.password

  # Add local-exec to echo instance ip, id and password on console
  provisioner "local-exec" {
    command = <<EOT
echo "K8s instance IP: ${tencentcloud_instance.web[0].public_ip}"
echo "K8s instance ID: ${tencentcloud_instance.web[0].id}"
echo "K8s instance login username: ${local.login_user} - Using ubuntu as image"
echo "K8s instance login password: ${var.password}"
EOT
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

# Deploy k3s to the instance
# K3s module guide: https://github.com/xunleii/terraform-module-k3s?tab=readme-ov-file
module "k3s" {
  depends_on = [ tencentcloud_instance.web ]
  source                   = "xunleii/k3s/module"
  k3s_version              = "latest"
  generate_ca_certificates = true
  global_flags = [
    "--tls-san ${tencentcloud_instance.web[0].public_ip}",
    "--write-kubeconfig-mode 644",
    "--disable=traefik",
    "--kube-controller-manager-arg bind-address=0.0.0.0",
    "--kube-proxy-arg metrics-bind-address=0.0.0.0",
    "--kube-scheduler-arg bind-address=0.0.0.0"
  ]
  k3s_install_env_vars = {}

  servers = {
    "k3s" = {
      ip = tencentcloud_instance.web[0].private_ip
      connection = {
        timeout  = "60s"
        type     = "ssh"
        host     = tencentcloud_instance.web[0].public_ip
        password = var.password
        user     = local.login_user
      }
    }
  }
}

resource "local_sensitive_file" "kubeconfig" {
  content  = module.k3s.kube_config
  filename = "${path.module}/config.yaml"
}
