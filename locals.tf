locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Project     = "ctse"
    Environment = var.environment
    Terraform   = "true"
  }

  # Environment-specific configurations
  environment_configs = {
    dev = {
      instance_type  = "t3.medium"
      min_size       = 1
      max_size       = 3
      desired_size   = 1
      kafka_replicas = 1
    }
    prod = {
      instance_type  = "m5.large"
      min_size       = 3
      max_size       = 6
      desired_size   = 3
      kafka_replicas = 3
    }
  }

  # Select configuration based on environment
  env    = var.environment == "production" ? "prod" : "dev"
  config = local.environment_configs[local.env]
}
