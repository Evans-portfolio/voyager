# Same rationale as postgres.tf's password relay: Terraform on voyager cannot reach
# the vaults data-plane endpoint, so the write happens via the jumpbox. The command
# Terraform logs only ever references a file path, never the webhook URL itself.
resource "local_sensitive_file" "slack_webhook_url" {
  content         = var.slack_webhook_url
  filename        = "${path.module}/.slack-webhook-url.tmp"
  file_permission = "0600"
}

resource "null_resource" "slack_webhook_url_kv" {
  triggers = {
    webhook_hash = sha256(var.slack_webhook_url)
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp -i ~/.ssh/jumpbox_rsa -o StrictHostKeyChecking=accept-new \
        ${local_sensitive_file.slack_webhook_url.filename} \
        azureuser@${azurerm_public_ip.jumpbox.ip_address}:/tmp/slack.tmp
      ssh -i ~/.ssh/jumpbox_rsa azureuser@${azurerm_public_ip.jumpbox.ip_address} \
        'az login --identity -o none && az keyvault secret set --vault-name ${azurerm_key_vault.test.name} --name alertmanager-slack-webhook --value "$(cat /tmp/slack.tmp)" -o none && rm -f /tmp/slack.tmp'
      rm -f ${local_sensitive_file.slack_webhook_url.filename}
    EOT
  }

  depends_on = [
    azurerm_role_assignment.jumpbox_keyvault_secrets_officer,
  ]
}
