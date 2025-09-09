variable "namespace" {
  description = "Kubernetes namespace for Rancher"
  type        = string
  default     = "cattle-system"
}

variable "chart_version" {
  description = "Version of the Rancher Helm chart"
  type        = string
  default     = "2.8.0" # Check for latest version
}

variable "cert_manager_version" {
  description = "Version of the cert-manager Helm chart"
  type        = string
  default     = "v1.13.3" # Check for latest version
}

variable "rancher_hostname" {
  description = "Hostname that Rancher will use"
  type        = string
}

variable "replica_count" {
  description = "Number of Rancher replicas"
  type        = number
  default     = 3
}

variable "admin_password" {
  description = "Admin password for Rancher"
  type        = string
  sensitive   = true
}
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}
