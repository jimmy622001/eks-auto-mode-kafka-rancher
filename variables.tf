

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "eks_endpoint" {
  description = "EKS cluster endpoint URL"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-west-1"
}

variable "availability_zones" {
  description = "List of availability zones for the region"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}
variable "namespace" {
  description = "Kubernetes namespace where Kafka will be deployed"
  type        = string
  default     = "kafka"
}

variable "chart_version" {
  description = "Version of the Kafka Helm chart"
  type        = string
  default     = "26.3.0" # You should check for the latest version
}

variable "storage_class" {
  description = "Storage class to use for Kafka persistence"
  type        = string
  default     = "gp3" # AWS EBS GP3 storage class
}

variable "replica_count" {
  description = "Number of Kafka brokers"
  type        = number
  default     = 3
}

variable "storage_size" {
  description = "Size of persistent volume for each Kafka broker"
  type        = string
  default     = "100Gi"
}

variable "resources" {
  description = "Resource requests and limits for Kafka pods"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

variable "replicas" {
  description = "Number of Kafka replicas"
  type        = number
  default     = 3
}

variable "kafka_version" {
  description = "Kafka version to deploy"
  type        = string
  default     = "7.5.0"
}
/*
variable "zookeeper_connect" {
  description = "Zookeeper connection string"
  type        = string
}
*/
