resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "25.8.0"

  set = [
    {
      name  = "server.persistentVolume.enabled"
      value = "true"
    },
    {
      name  = "server.persistentVolume.size"
      value = "50Gi"
    }
  ]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "7.0.3"

  set = [
    {
      name  = "persistence.enabled"
      value = "true"
    },
    {
      name  = "persistence.size"
      value = "10Gi"
    },
    {
      name  = "adminPassword"
      value = var.grafana_admin_password
    },
    {
      name  = "service.type"
      value = "LoadBalancer"
    }
  ]
}
# Security scanning secrets management
resource "aws_secretsmanager_secret" "security_scanning" {
  name        = "${var.environment}-${var.cluster_name}-security-scanning-secrets"
  description = "Secrets for security scanning tools in monitoring"

  tags = {
    Environment = var.environment
    Component   = "security-monitoring"
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "security_scanning" {
  secret_id = aws_secretsmanager_secret.security_scanning.id
  secret_string = jsonencode({
    sonarqube_token = var.sonarqube_token
    snyk_token      = var.snyk_token
    zap_api_key     = var.zap_api_key
    trivy_token     = var.trivy_token
  })
}



# Deploy Trivy operator for continuous container scanning
resource "helm_release" "trivy_operator" {
  name             = "trivy-operator"
  repository       = "https://aquasecurity.github.io/helm-charts/"
  chart            = "trivy-operator"
  namespace        = "trivy-system"
  create_namespace = true

  set = [
    {
      name  = "trivy.ignoreUnfixed"
      value = "true"
    }
  ]
}

# TODO: SecureCodeBox implementation
# Commented out until we can resolve the chart availability issue
# resource "helm_release" "security_monitoring" {
#   name             = "security-monitoring"
#   repository       = "https://charts.securecodebox.io"
#   chart            = "securecodebox"
#   namespace        = "security-monitoring"
#   create_namespace = true
#
#   set = [
#     {
#       name  = "operator.secretName"
#       value = aws_secretsmanager_secret.security_scanning.name
#     }
#   ]
# }
