variable "libvirt_uri" {
  description = "Connection URI for libvirt"
  type        = string
  default     = "qemu:///system"
}

variable "network_name" {
  description = "Name of the pre-existing libvirt management network"
  type        = string
  default     = "mgmt"
}

variable "pool_name" {
  description = "Name of the pre-existing libvirt directory pool"
  type        = string
  default     = "homelab-dir"
}

variable "ubuntu_image_url" {
  description = "URL of the Ubuntu cloud image used for the node"
  type        = string
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key injected by cloud-init"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "node_name" {
  description = "Name of the K3s node domain"
  type        = string
  default     = "k3s-node"
}

variable "node_mac" {
  description = "Stable MAC address used for the node DHCP lease"
  type        = string
  default     = "52:54:00:11:22:33"
}

variable "disk_size" {
  description = "Size of the node root volume in bytes"
  type        = number
  default     = 20 * 1024 * 1024 * 1024
}
