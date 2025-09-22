variable "aws_region" {
  type        = string
  description = "AWS region"

}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}
variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDR blocks"

}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDR blocks"

}
variable "environment" {
  type        = string
  description = "Environment name"
}

variable "rancher_admin_password" {
  type      = string
  sensitive = true
}

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
variable "replica_count" {
  description = "Number of Kafka brokers"
  type        = number
}
variable "system_node_group" {
  description = "Configuration for the system node group"
  type = object({
    desired_size = number,
    min_size     = number
  })
}
variable "rancher_hostname" {
  description = "Rancher hostname"
  type        = string
}
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}
variable "endpoint_private_access" {
  description = "Enable private API server endpoint access for EKS"
  type        = bool
}
variable "enable_guardrails" {
  description = "Enable Control Tower guardrails"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.20.0.0/19"
}

variable "organizational_units" {
  description = "List of organizational units to create"
  type        = list(string)
  default     = ["Security", "Infrastructure", "Workloads", "Sandbox"]
}

variable "enable_service_control_policies" {
  description = "Enable Service Control Policies"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
  default     = {}
}
variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}
variable "endpoint_public_access" {
  description = "Enable public API server endpoint access for EKS"
  type        = bool
}
variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)

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