resource "libvirt_volume" "ubuntu_base" {
  name   = "k3s-ubuntu-base.qcow2"
  pool   = var.pool_name
  format = "qcow2"
  source = var.ubuntu_image_url
}

resource "libvirt_volume" "k8s_node" {
  name           = "k3s-node.qcow2"
  pool           = var.pool_name
  format         = "qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.disk_size
}

resource "libvirt_cloudinit_disk" "k8s_cloudinit" {
  name = "k3s-cloudinit.iso"
  pool = var.pool_name

  user_data = templatefile("${path.module}/cloud-init.yml.tftpl", {
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })

  network_config = templatefile("${path.module}/network-config.yml.tftpl", {})
}

resource "libvirt_domain" "k8s_node" {
  name   = var.node_name
  memory = 4096
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.k8s_cloudinit.id

  network_interface {
    network_name   = var.network_name
    mac            = var.node_mac
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.k8s_node.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}
