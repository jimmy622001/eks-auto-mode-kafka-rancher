variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version to use for the EKS cluster"
  default     = "1.32"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "10.20.0.0/19"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDR blocks"
  default     = ["10.20.0.0/21", "10.20.8.0/21", "10.20.16.0/21"]
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDR blocks"
  default     = ["10.20.24.0/23", "10.20.26.0/23", "10.20.28.0/23"]
}

variable "endpoint_private_access" {
  type        = bool
  description = "Enable private API server endpoint access"
  default     = true
}

variable "endpoint_public_access" {
  type        = bool
  description = "Enable public API server endpoint access"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "general_purpose_node_group" {
  type = object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
  })
  description = "Configuration for the general purpose node group"
  default = {
    desired_size   = 2
    min_size       = 2
    max_size       = 5
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
  }
}

variable "system_node_group" {
  type = object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
  })
  description = "Configuration for the system node group"
  default = {
    desired_size   = 2
    min_size       = 2
    max_size       = 3
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
  }
}
variable "namespace" {
  type        = string
  description = "Kubernetes namespace for EKS components"
  default     = "kube-system"
}
variable "aws_region" {
  type        = string
  description = "AWS region"
}
