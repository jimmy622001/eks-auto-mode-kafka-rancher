
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.13.3"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

resource "helm_release" "rancher" {
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  namespace        = "cattle-system"
  create_namespace = true
  version          = "2.7.9"

  depends_on = [helm_release.cert_manager]

  set = [
    {
      name  = "hostname"
      value = var.rancher_hostname
    },
    {
      name  = "replicas"
      value = tostring(var.replica_count)
    },
    {
      name  = "bootstrapPassword"
      value = var.admin_password
    }
  ]
}