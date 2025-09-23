variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

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

variable "trivy_token" {
  description = "Trivy authentication token"
  type        = string
  sensitive   = true
  default     = ""
}
