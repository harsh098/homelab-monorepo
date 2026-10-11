# Preserve the detached mail data volume and its existing contents for recovery.
resource "libvirt_volume" "mail_data" {
  name   = "mail-data.qcow2"
  pool   = var.pool_name
  format = "qcow2"
  size   = 20 * 1024 * 1024 * 1024

  lifecycle {
    prevent_destroy = true
  }
}

# Keep the original restic password in Terraform state for restoring archived mail.
resource "random_password" "mail_restic" {
  length  = 48
  special = false

  lifecycle {
    prevent_destroy = true
  }
}

output "mail_backup_password" {
  value     = random_password.mail_restic.result
  sensitive = true
}
