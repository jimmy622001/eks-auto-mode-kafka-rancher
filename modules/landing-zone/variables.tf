variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Organization and Control Tower Configuration
variable "organization_name" {
  description = "Name of the AWS Organization"
  type        = string
}

variable "organization_email" {
  description = "Email address for the AWS Organizations management account"
  type        = string
}

variable "log_archive_email" {
  description = "Email address for the log archive account"
  type        = string
}

variable "audit_email" {
  description = "Email address for the audit account"
  type        = string
}

# EKS Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.20.0.0/19"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.20.0.0/21", "10.20.8.0/21", "10.20.16.0/21"]
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.20.24.0/23", "10.20.26.0/23", "10.20.28.0/23"]
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28" # Updated to a valid version
}

variable "organizational_units" {
  description = "List of organizational units to create"
  type        = list(string)
  default     = ["Security", "Infrastructure", "Workloads", "Sandbox"]
}

# Rancher Configuration
variable "rancher_hostname" {
  description = "Hostname for Rancher"
  type        = string
}

variable "rancher_admin_password" {
  description = "Admin password for Rancher"
  type        = string
  sensitive   = true
}

variable "replica_count" {
  description = "Number of Rancher replicas"
  type        = number
  default     = 3
}

variable "system_node_group" {
  description = "Configuration for the system node group"
  type = object({
    desired_size = number,
    min_size     = number
  })
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint access for EKS"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint access for EKS"
  type        = bool
  default     = true
}