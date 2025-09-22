variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Jenkins will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Jenkins Master Configuration
variable "jenkins_master_instance_type" {
  description = "Instance type for Jenkins master"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_master_volume_size" {
  description = "Root volume size for Jenkins master (GB)"
  type        = number
  default     = 50
}

variable "jenkins_admin_password" {
  description = "Admin password for Jenkins"
  type        = string
  sensitive   = true
}

variable "jenkins_public_key" {
  description = "Public key for Jenkins EC2 instances"
  type        = string
}

# Jenkins Agents Configuration
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

# GitHub Integration
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

# Optional Features
variable "enable_jenkins_alb" {
  description = "Enable Application Load Balancer for Jenkins"
  type        = bool
  default     = false
}

# Cost Optimization Settings
variable "enable_auto_shutdown" {
  description = "Enable automatic shutdown of Jenkins master during off-hours"
  type        = bool
  default     = true
}

variable "shutdown_schedule" {
  description = "Cron expression for Jenkins master shutdown (UTC)"
  type        = string
  default     = "0 22 * * MON-FRI" # 10 PM UTC, Monday to Friday
}

variable "startup_schedule" {
  description = "Cron expression for Jenkins master startup (UTC)"
  type        = string
  default     = "0 8 * * MON-FRI" # 8 AM UTC, Monday to Friday
}

variable "agent_idle_timeout" {
  description = "Time in minutes before idle agents are terminated"
  type        = number
  default     = 30
}

# Build Configuration
variable "default_build_timeout" {
  description = "Default build timeout in minutes"
  type        = number
  default     = 60
}

variable "concurrent_builds" {
  description = "Maximum number of concurrent builds"
  type        = number
  default     = 3
}

# Notification Settings
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
