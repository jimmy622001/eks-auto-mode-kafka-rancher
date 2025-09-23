terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }

  # Temporarily using local backend for bootstrapping
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      local.common_tags,
      {
        ManagedBy = "terraform"
      }
    )
  }
}

# First, deploy Landing Zone
module "landing_zone" {
  source                 = "./modules/landing-zone"
  aws_region             = var.aws_region
  audit_email            = var.audit_email
  organization_name      = var.organization_name
  cluster_name           = var.cluster_name
  system_node_group      = var.system_node_group
  rancher_hostname       = var.rancher_hostname
  rancher_admin_password = var.rancher_admin_password


  log_archive_email  = var.log_archive_email
  organization_email = var.organization_email
}

# Then Control Tower
module "control_tower" {
  source = "./modules/control-tower"

  aws_region         = var.aws_region
  organization_email = var.organization_email
  log_archive_email  = var.log_archive_email
  audit_email        = var.audit_email
}

# Then deploy EKS

module "eks" {
  source             = "./modules/eks"
  aws_region         = var.aws_region
  cluster_name       = "${var.cluster_name}-${local.env}" # Append environment to cluster name
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones
  vpc_cidr           = var.vpc_cidr
  environment        = var.environment

  # Node group configuration from environment-specific settings
  general_purpose_node_group = {
    desired_size   = local.config.desired_size
    min_size       = local.config.min_size
    max_size       = local.config.max_size
    instance_types = [local.config.instance_type]
    capacity_type  = "ON_DEMAND"
  }

  system_node_group = var.system_node_group

  tags = merge(
    local.common_tags,
    {
      ManagedBy = "terraform"
    }
  )

  depends_on = [module.control_tower]
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}


provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name
      ]
    }
  }
}

# Commented out until EKS is running
# module "kafka" {
#   source     = "./modules/kafka"
#   depends_on = [module.eks]
# }

module "rancher" {
  source     = "./modules/rancher"
  depends_on = [module.eks]

  cluster_name           = module.eks.cluster_name
  rancher_hostname       = "rancher.${var.cluster_name}.example.com"
  replica_count          = var.replica_count
  aws_region             = var.aws_region
  log_archive_email      = var.log_archive_email
  audit_email            = var.audit_email
  organization_email     = var.organization_email
  organization_name      = var.organization_name
  environment            = var.environment
  system_node_group      = var.system_node_group
  rancher_admin_password = var.rancher_admin_password
}


module "monitoring" {
  source     = "./modules/monitoring"
  depends_on = [module.eks]

  environment            = var.environment
  cluster_name           = var.cluster_name
  grafana_admin_password = var.grafana_admin_password
}

# Jenkins CI/CD with cost optimization
module "jenkins" {
  source     = "./modules/jenkins"
  depends_on = [module.eks]

  cluster_name    = var.cluster_name
  aws_region      = var.aws_region
  vpc_id          = module.eks.vpc_id
  vpc_cidr        = var.vpc_cidr
  private_subnets = module.eks.private_subnets
  environment     = var.environment

  # Jenkins Configuration
  jenkins_admin_password = var.jenkins_admin_password
  jenkins_public_key     = var.jenkins_public_key
  github_token           = var.github_token
  github_webhook_secret  = var.github_webhook_secret

  # Instance Configuration
  jenkins_master_instance_type = var.jenkins_master_instance_type
  jenkins_agent_instance_type  = var.jenkins_agent_instance_type
  max_jenkins_agents           = var.max_jenkins_agents
  spot_max_price               = var.spot_max_price

  # Cost Optimization
  enable_auto_shutdown = var.enable_jenkins_auto_shutdown
  shutdown_schedule    = var.jenkins_shutdown_schedule
  startup_schedule     = var.jenkins_startup_schedule

  # Optional Features
  enable_jenkins_alb = var.enable_jenkins_alb

  # Notifications
  slack_webhook_url  = var.slack_webhook_url
  notification_email = var.notification_email

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Project     = "ctse"
  }
}
