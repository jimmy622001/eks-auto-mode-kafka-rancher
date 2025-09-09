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