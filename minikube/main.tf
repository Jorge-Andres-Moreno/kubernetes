locals {
  cluster_name = "minikube"
}

resource "minikube_cluster" "this" {
  driver       = "docker"
  cluster_name = local.cluster_name
  addons = [
    "ingress",
    "dashboard",
  ]
}