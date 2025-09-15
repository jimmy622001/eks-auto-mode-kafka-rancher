
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
}


provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ctse"
      Environment = var.environment
      Terraform   = "true"
    }
  }
}

module "eks" {
  source = "./modules/eks"
  aws_region = var.aws_region
  cluster_name = var.cluster_name
  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
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


module "rancher" {
  source     = "./modules/rancher"
  depends_on = [module.eks]

  cluster_name     = module.eks.cluster_name
  rancher_hostname = "rancher.${var.cluster_name}.example.com"
  admin_password   = var.rancher_admin_password
}

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Add SSM policy attachment for node role
resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}
# Commented out until EKS is running
# module "kafka" {
#   source     = "./modules/kafka"
#   depends_on = [module.eks]
# }

# Commented out until EKS is running
# module "rancher" {
#   source     = "./modules/rancher"
#   depends_on = [module.eks]
#
#   cluster_name     = module.eks.cluster_name
#   rancher_hostname = "rancher.${var.cluster_name}.example.com"
#   admin_password   = var.rancher_admin_password
# }
