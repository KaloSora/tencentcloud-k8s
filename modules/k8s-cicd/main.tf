locals {
  ssh_private_key = var.ssh_key_private_key_path
  ssh_public_key = var.ssh_key_public_key_path
  init_script = "cicd_init.sh"
  init_script_tpl = "cicd_init.sh.tpl"
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
    private_key = local.ssh_private_key
    port        = 22
    timeout     = "2m"
  }
  
  # Upload private key for server connection
#   provisioner "file" {
#     content     = local.ssh_private_key
#     destination = local.cvm_key_server_private_path
#   }

#   # Local script upload with terraform template file
#   provisioner "file" {
#     destination = "/tmp/${local.init_script}"
#     content = templatefile(
#       "${path.module}/script/${local.init_script_tpl}",
#       {
#         "instance_ip" = "${each.value.public_ip}"
#       }
#     )
#   }

#   # Remote-exec provisioner to run commands on the CVM instance via SSH
#   provisioner "remote-exec" {
#     inline = [

#       "chmod 600 ${local.cvm_key_server_private_path}",
#       "echo 'IdentityFile ${local.cvm_key_server_private_path}' >> /root/.ssh/config",
#       "chmod 600 /root/.ssh/config",
#       "chmod +x /tmp/${local.init_script}",

#       # Run the setup script
#       "sudo sh /tmp/${local.init_script} > /tmp/${each.value.instance_name}.log 2>&1",
#       "echo 'Execution completed!'"
#     ]
#   }

#   # Download log file back to local for debugging
#   provisioner "local-exec" {
#     command = <<-EOT
#       mkdir -p ${path.module}/logs
#       scp -i ${local.cvm_key_filename} \
#           -o StrictHostKeyChecking=no \
#           ${var.cvm_login_user}@${each.value.public_ip}:/tmp/${each.value.instance_name}.log \
#           ${path.module}/logs/${each.value.instance_name}.log
#     EOT
#   }
}
