# First, install cert-manager as an EKS add-on
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.14.3"
  atomic           = true
  timeout          = 600

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

resource "local_file" "rancher_values" {
  content = yamlencode({
    hostname          = var.rancher_hostname
    replicas          = var.replica_count
    bootstrapPassword = var.admin_password
    ingress = {
      tls = {
        source = "rancher"
      }
    }
  })
  filename = "${path.module}/rancher-values.yaml"
}

resource "helm_release" "rancher" {
  depends_on = [time_sleep.wait_for_cert_manager, local_file.rancher_values]

  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/latest"
  chart            = "rancher"
  namespace        = var.namespace
  create_namespace = true
  version          = "2.7.5"
  atomic           = true
  timeout          = 600

  values = [
    local_file.rancher_values.content
  ]
}