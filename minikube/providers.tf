terraform {
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "0.2.4"
    }
  }
}

provider "minikube" {
  kubernetes_version = "v1.26.1"
}
