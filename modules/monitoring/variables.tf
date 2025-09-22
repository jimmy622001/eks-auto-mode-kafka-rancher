variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# Security scanning secrets
variable "sonarqube_token" {
  description = "SonarQube authentication token"
  type        = string
  sensitive   = true
}

variable "snyk_token" {
  description = "Snyk authentication token"
  type        = string
  sensitive   = true
}

variable "zap_api_key" {
  description = "OWASP ZAP API key"
  type        = string
  sensitive   = true
}

variable "trivy_token" {
  description = "Trivy authentication token"
  type        = string
  sensitive   = true
}