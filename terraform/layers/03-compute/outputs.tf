output "k8s_node_ip" {
  description = "DHCP address reported by libvirt for the Kubernetes node"
  value       = try(libvirt_domain.k8s_node.network_interface[0].addresses[0], null)
}

output "k8s_node_mac" {
  description = "MAC address of the Kubernetes node"
  value       = var.node_mac
}

output "kubeconfig_path" {
  description = "Path populated by the orchestration playbook"
  value       = "${path.module}/kubeconfig"
}
