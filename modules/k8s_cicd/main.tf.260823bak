locals {
  ssh_private_key = var.ssh_key_private_key_path
  ssh_private_key_content = file(var.ssh_key_private_key_path)
  init_script = "cicd_init.sh"
  init_script_tpl = "cicd_init.sh.tpl"
  storage_class_name = "cfs-shared-storageclass"
  storage_class_yaml = "/tmp/k8s_storageclass.yaml"
  storage_class_yaml_tpl = "k8s_storageclass.yaml.tpl"
  log_file_name = "k8s-cicd.log"
}

# Setup the CICD base on the template file
# It will connect to K8s cluster on Tencent Cloud CVM
resource "null_resource" "k8s_cicd_provision" {
  
  # Condition: once script changed, this module will re-run
  triggers = {
    script_hash = filemd5("${path.module}/script/${local.init_script_tpl}")
  }

  connection {
    type        = "ssh"
    host        = var.k8s_master_public_ip
    user        = var.cvm_login_user
    private_key = local.ssh_private_key_content
    port        = 22
    timeout     = "2m"
  }

  # Local script upload with terraform template file
  provisioner "file" {
    destination = "/tmp/${local.init_script}"
    content = templatefile(
      "${path.module}/script/${local.init_script_tpl}",
      {
        "STORAGE_CLASS_YAML" = "${local.storage_class_yaml}"
        "STORAGE_CLASS_NAME" = "${local.storage_class_name}"
        "INGRESS_NGINX_VERSION" = "${var.ingress_nginx_version}"
        "HARBOR_VERSION" = "${var.harbor_version}"
        "HARBOR_URL" = "${var.harbor_url}"
      }
    )
  }

  # Upload K8s storage class yaml file with template file
  provisioner "file" {
      destination = "${local.storage_class_yaml}"
      content = templatefile(
        "${path.module}/script/${local.storage_class_yaml_tpl}",
        {
          "VPC_ID" = "${var.vpc_id}"
          "SUBNET_ID" = "${var.subnet_id}"
          "CFS_PGROUP_ID" = "${var.cfs_pgroup_id}"
          "STORAGE_CLASS_NAME" = "${local.storage_class_name}"
        }
    )
  }

  # Remote-exec provisioner to run commands on the CVM instance via SSH
  provisioner "remote-exec" {
    inline = [

      "chmod +x /tmp/${local.init_script}",
      "chmod +x ${local.storage_class_yaml}",

      # Run the setup script
      "sudo sh /tmp/${local.init_script} > /tmp/${local.log_file_name} 2>&1",
      "echo 'K8s CICD Execution completed!'"
    ]
  }

  # Download log file back to local for debugging
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/logs
      scp -i ${local.ssh_private_key} \
          -o StrictHostKeyChecking=no \
          ${var.cvm_login_user}@${var.k8s_master_public_ip}:/tmp/${local.log_file_name} \
          ${path.module}/logs/${local.log_file_name}
    EOT
  }
}
