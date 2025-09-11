variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "rancher_hostname" {
  type        = string
  description = "Hostname for Rancher"
}

variable "admin_password" {
  type        = string
  description = "Admin password for Rancher"
  sensitive   = true
}

variable "replica_count" {
  type        = number
  description = "Number of Rancher replicas"
  default     = 3
}