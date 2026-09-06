locals {
  cvm_key_name = "cvm_ssh_key"
  cvm_key_filename = var.ssh_key_private_key_path
  cvm_key_filename_pub = var.ssh_key_public_key_path
  cvm_key_server_private_path = "/root/.ssh/cluster_key"
  kube_config_path = "/Users/yihui.li/YIHUI/github_workspace/tencentcloud-k8s/modules/kubeconfig/config"

  init_script = "init.sh"
  init_script_tpl = "init.sh.tpl"

  # Set template file variables for init.sh.tpl
  init_var_k8s_version = var.k8s_version
  init_var_k8s_cidr = var.k8s_cidr
  init_var_cfsssl_version = var.k8s_cfssl_version
  init_var_cri_dockerd_version = var.k8s_cri_dockerd_version
  init_var_helm_version = var.k8s_helm_version

  # Set instance list by cost saving mode
  final_k8s_cluster = var.k8s_cost_saving_mode ? {
      master1 = var.k8s_cluster["master1"]
      node1   = var.k8s_cluster["node1"]
  } : var.k8s_cluster

  ### Dynamic variable after cvm creation below ###
  # Filter master instances for master provisioning
  master_instances = {
    for k, inst in tencentcloud_instance.k8s_server : k => inst
    if can(regex("master", inst.instance_name))
  }

  # Get the 1st master private ip
  first_master_key = one([for k, cfg in local.final_k8s_cluster : k if try(cfg.is_first_master, "") == "true"])
  first_master_instance = local.first_master_key != null ? tencentcloud_instance.k8s_server[local.first_master_key] : null
  master_private_ip = local.first_master_instance != null ? local.first_master_instance.private_ip : ""
  master_public_ip  = local.first_master_instance != null ? local.first_master_instance.public_ip : ""

  # master_private_ip = length(local.master_instances_list) > 0 ? local.master_instances_list[0].private_ip : ""
  # master_public_ip  = length(local.master_instances_list) > 0 ? local.master_instances_list[0].public_ip : ""
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

resource "local_file" "cvm_public_key" {
  content  = tls_private_key.cvm_key.public_key_openssh
  filename = "${local.cvm_key_filename_pub}"
}

# Upload keypair to tencent cloud
resource "tencentcloud_key_pair" "cvm-key" {
  key_name   = local.cvm_key_name
  public_key = tls_private_key.cvm_key.public_key_openssh
}

# Create a k8s server
resource "tencentcloud_instance" "k8s_server" {

  for_each = local.final_k8s_cluster

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
    CPU  = tostring(each.value.cpu_core_count)
    Mem  = tostring(each.value.memory_size)
    Purpose = each.value.tags.purpose
    Role = each.value.tags.role
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
    "ACCEPT#0.0.0.0/0#10254#TCP", # For nginx ingress health check port
    "ACCEPT#0.0.0.0/0#6443#TCP",
    "ACCEPT#0.0.0.0/0#443#TCP", # Allow HTTPS traffic for Ingress-nginx
    "ACCEPT#0.0.0.0/0#80#TCP",  # For Ingress-nginx
    "ACCEPT#172.16.0.0/12#10250#TCP", # For HongKong AZ inbound / outbound
    "ACCEPT#172.16.0.0/12#ALL#ALL",
    "ACCEPT#192.168.0.0/16#ALL#ALL", # Allow K8s cluster internal communication within private network
    "ACCEPT#10.96.0.0/12#ALL#ALL",  # Allow K8s cluster service CIDR
    "ACCEPT#0.0.0.0/0#4789#UDP" # Allow VXLAN overlay network traffic for CNI plugin Calico/Flannel
  ]

  egress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL",
    "ACCEPT#172.16.0.0/12#ALL#ALL",
    "ACCEPT#192.168.0.0/16#ALL#ALL",
    "ACCEPT#0.0.0.0/0#4789#UDP", # Allow VXLAN overlay network traffic for CNI plugin Calico/Flannel
    "ACCEPT#10.96.0.0/12#ALL#ALL"  # Allow K8s cluster service CIDR
  ]
}


# Setup the CVM for K8s Master
resource "null_resource" "master_provision" {

  for_each = {
    for k, inst in tencentcloud_instance.k8s_server : k => inst
    if can(regex("master", inst.instance_name))
  }

  depends_on = [tencentcloud_instance.k8s_server]
  
  # Condition: once script changed, this module will re-run
  triggers = {
    script_hash = filemd5("${path.module}/script/${local.init_script_tpl}")
    instance_id = each.value.id
  }

  connection {
    type        = "ssh"
    host        = each.value.public_ip
    user        = var.cvm_login_user
    private_key = tls_private_key.cvm_key.private_key_pem
    port        = 22
    timeout     = "2m"
  }
  
  # Upload private key for server connection
  provisioner "file" {
    content     = tls_private_key.cvm_key.private_key_pem
    destination = local.cvm_key_server_private_path
  }

  # Local script upload with terraform template file
  provisioner "file" {
    destination = "/tmp/${local.init_script}"
    content = templatefile(
      "${path.module}/script/${local.init_script_tpl}",
      {
        "instance_ip" = "${each.value.public_ip}"
        "instance_id" = "${each.value.id}"
        "instance_role"  = "master"
        "instance_name" = "${each.value.instance_name}"
        "instance_master_ip" = "${each.value.private_ip}" ## This param won't be used by master vm, can ignore
        "ssh_key_path" = "${local.cvm_key_server_private_path}"
        "ssh_private_key" = "${local.cvm_key_filename}"
        "cfs_enabled" = "${var.cvm_cfs_enabled}"
        "cfs_secret_id" = "${var.cvm_cfs_secret_id}"
        "cfs_secret_key" = "${var.cvm_cfs_secret_key}"
        "cfs_csi_secret" = "${var.cvm_cfs_csi_secret}"
        "k8s_cfssl_version"  = "${local.init_var_cfsssl_version}"
        "k8s_cri_dockerd_version" = "${local.init_var_cri_dockerd_version}"
        "k8s_version" = "${local.init_var_k8s_version}"
        "k8s_cidr" = "${local.init_var_k8s_cidr}"
        "k8s_cfssl_enabled" = "${var.k8s_cfssl_enabled}"
        "k8s_helm_enabled" = "${var.k8s_helm_enabled}"
        "k8s_helm_version" = "${var.k8s_helm_version}"
        "k8s_first_master_flag" = try(local.final_k8s_cluster[each.key].is_first_master, "") == "true" ? "true" : "false"
        "k8s_first_master_ip" = "${local.master_private_ip}"
      }
    )
  }

  # Remote-exec provisioner to run commands on the CVM instance via SSH
  provisioner "remote-exec" {
    inline = [

      "chmod 600 ${local.cvm_key_server_private_path}",
      "echo 'IdentityFile ${local.cvm_key_server_private_path}' >> /root/.ssh/config",
      "chmod 600 /root/.ssh/config",
      "chmod +x /tmp/${local.init_script}",

      # Run the setup script
      "sudo sh /tmp/${local.init_script} > /tmp/${each.value.instance_name}.log 2>&1",
      "echo 'Execution completed!'"
    ]
  }

  # Download log file back to local for debugging
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/logs
      scp -i ${local.cvm_key_filename} \
          -o StrictHostKeyChecking=no \
          ${var.cvm_login_user}@${each.value.public_ip}:/tmp/${each.value.instance_name}.log \
          ${path.module}/logs/${each.value.instance_name}.log
    EOT
  }
}

# Setup the CVM for K8s Node
resource "null_resource" "node_provision" {

  for_each = {
    for k, inst in tencentcloud_instance.k8s_server : k => inst
    if can(regex("node", inst.instance_name))
  }

  # Wait for master initialization before provisioning node
  # Otherwise the join command will not be generated and the node setup will fail
  depends_on = [null_resource.master_provision]
  
  # Condition: once script changed, this module will re-run
  triggers = {
    script_hash = filemd5("${path.module}/script/${local.init_script_tpl}")
    instance_id = each.value.id
  }

  connection {
    type        = "ssh"
    host        = each.value.public_ip
    user        = var.cvm_login_user
    private_key = tls_private_key.cvm_key.private_key_pem
    port        = 22
    timeout     = "2m"
  }
  
  # Upload private key for server connection
  provisioner "file" {
    content     = tls_private_key.cvm_key.private_key_pem
    destination = local.cvm_key_server_private_path
  }

  # Local script upload with terraform template file
  provisioner "file" {
    destination = "/tmp/${local.init_script}"
    content = templatefile(
      "${path.module}/script/${local.init_script_tpl}",
      {
        "instance_ip" = "${each.value.public_ip}"
        "instance_id" = "${each.value.id}"
        "instance_role"  = "node"
        "instance_name" = "${each.value.instance_name}"
        "instance_master_ip" = "${local.master_private_ip}"
        "ssh_key_path" = "${local.cvm_key_server_private_path}"
        "ssh_private_key" = "${local.cvm_key_filename}"
        "cfs_enabled" = "${var.cvm_cfs_enabled}"
        "cfs_secret_id" = "${var.cvm_cfs_secret_id}"
        "cfs_secret_key" = "${var.cvm_cfs_secret_key}"
        "cfs_csi_secret" = "${var.cvm_cfs_csi_secret}"
        "k8s_cfssl_version"  = "${local.init_var_cfsssl_version}"
        "k8s_cri_dockerd_version" = "${local.init_var_cri_dockerd_version}"
        "k8s_version" = "${local.init_var_k8s_version}"
        "k8s_cidr" = "${local.init_var_k8s_cidr}"
        "k8s_cfssl_enabled" = "${var.k8s_cfssl_enabled}"
        "k8s_helm_enabled" = "${var.k8s_helm_enabled}"
        "k8s_helm_version" = "${var.k8s_helm_version}"
        "k8s_first_master_flag" = try(local.final_k8s_cluster[each.key].is_first_master, "") == "true" ? "true" : "false"
        "k8s_first_master_ip" = "${local.master_private_ip}"
      }
    )
  }

  # Remote-exec provisioner to run commands on the CVM instance via SSH
  provisioner "remote-exec" {
    inline = [

      "chmod 600 ${local.cvm_key_server_private_path}",
      "echo 'IdentityFile ${local.cvm_key_server_private_path}' >> /root/.ssh/config",
      "chmod 600 /root/.ssh/config",
      "chmod +x /tmp/${local.init_script}",

      # Run the setup script
      "sudo sh /tmp/${local.init_script} > /tmp/${each.value.instance_name}.log 2>&1",
      "echo 'Execution completed!'"
    ]
  }

  # Download log file back to local for debugging
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/logs
      scp -i ${local.cvm_key_filename} \
          -o StrictHostKeyChecking=no \
          ${var.cvm_login_user}@${each.value.public_ip}:/tmp/${each.value.instance_name}.log \
          ${path.module}/logs/${each.value.instance_name}.log
    EOT
  }
}

### Download kubeconfig file from master node to local machine for kubectl access
resource "null_resource" "download_kubeconfig" {
  depends_on = [null_resource.master_provision]

  connection {
    type        = "ssh"
    host        = local.master_public_ip
    user        = var.cvm_login_user
    private_key = tls_private_key.cvm_key.private_key_pem
    port        = 22
    timeout     = "2m"
  }

  # Download kubeconfig file back to local for debugging
  # To verify: kubectl --kubeconfig=./kubeconfig/config get nodes
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/logs
      scp -i ${local.cvm_key_filename} \
          -o StrictHostKeyChecking=no \
          ${var.cvm_login_user}@${local.master_public_ip}:~/.kube/config \
          ${local.kube_config_path}
      
      perl -pi -e 's/certificate-authority-data:.*//' ${local.kube_config_path}
      perl -pi -e 's|server: https://[0-9.]+:6443|server: https://${local.master_public_ip}:6443|' ${local.kube_config_path}
      perl -pi -e 's|(server: https://${local.master_public_ip}:6443)|$1\n    insecure-skip-tls-verify: true|' ${local.kube_config_path}
    EOT
  }
}

### Tag k8s node base on existing CVM tag
resource "null_resource" "k8s_label_nodes" {
  depends_on = [null_resource.download_kubeconfig, null_resource.node_provision]

  # Listen node instance tag
  triggers = {
    # When the node tag changed, it will be trigger again
    node_tags = jsonencode({
      for k, inst in tencentcloud_instance.k8s_server : k => inst.tags["Purpose"]
      if can(regex("node", inst.instance_name))
    })
    # When the node name changed, it will be trigger again
    node_names = jsonencode([
      for k, inst in tencentcloud_instance.k8s_server : inst.instance_name
      if can(regex("node", inst.instance_name))
    ])
  }

  provisioner "local-exec" {
    command = <<-EOT
      KUBECONFIG="${local.kube_config_path}"
      
      # Waiting for node ready
      kubectl --kubeconfig="$KUBECONFIG" wait --for=condition=Ready nodes --all --timeout=300s

      # Tag each node
      %{ for key, inst in tencentcloud_instance.k8s_server ~}
        %{ if can(regex("node", inst.instance_name)) ~}
          echo "Labeling node ${inst.instance_name} with purpose=${inst.tags["Purpose"]}"
          kubectl --kubeconfig="$KUBECONFIG" label nodes ${inst.instance_name} purpose="${inst.tags["Purpose"]}" --overwrite || echo "Label failed for ${inst.instance_name}"
        %{ endif ~}
      %{ endfor ~}
    EOT
  }
}