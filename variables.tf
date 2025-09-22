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

# Jenkins CI/CD Variables
variable "jenkins_admin_password" {
  description = "Admin password for Jenkins"
  type        = string
  sensitive   = true
}

variable "jenkins_public_key" {
  description = "Public key for Jenkins EC2 instances"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for webhook integration"
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "Secret for GitHub webhook validation"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jenkins_master_instance_type" {
  description = "Instance type for Jenkins master"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_agent_instance_type" {
  description = "Instance type for Jenkins agents"
  type        = string
  default     = "t3.large"
}

variable "max_jenkins_agents" {
  description = "Maximum number of Jenkins agents"
  type        = number
  default     = 5
}

variable "spot_max_price" {
  description = "Maximum price for Spot instances (per hour)"
  type        = string
  default     = "0.10"
}

variable "enable_jenkins_auto_shutdown" {
  description = "Enable automatic shutdown of Jenkins master during off-hours"
  type        = bool
  default     = true
}

variable "jenkins_shutdown_schedule" {
  description = "Cron expression for Jenkins master shutdown (UTC)"
  type        = string
  default     = "0 22 * * MON-FRI" # 10 PM UTC, Monday to Friday
}

variable "jenkins_startup_schedule" {
  description = "Cron expression for Jenkins master startup (UTC)"
  type        = string
  default     = "0 8 * * MON-FRI" # 8 AM UTC, Monday to Friday
}

variable "enable_jenkins_alb" {
  description = "Enable Application Load Balancer for Jenkins"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for build notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "notification_email" {
  description = "Email address for build notifications"
  type        = string
  default     = ""
}
