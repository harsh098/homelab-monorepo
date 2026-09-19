resource "helm_release" "headlamp" {
  name             = "headlamp"
  repository       = "https://kubernetes-sigs.github.io/headlamp/"
  chart            = "headlamp"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  # Keep the dashboard ClusterIP-only. Access it with kubectl port-forward;
  # authentication and exposure can be configured separately after deployment.
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "clusterRoleBinding.create"
    value = "true"
  }

  set {
    name  = "clusterRoleBinding.clusterRoleName"
    value = "cluster-admin"
  }
}
