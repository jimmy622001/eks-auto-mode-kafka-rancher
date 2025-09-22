# EKS Auto-Mode with Kafka and Rancher

This project provides Infrastructure as Code (IaC) for deploying:
- Amazon EKS cluster
- AWS Control Tower Landing Zone
- Apache Kafka cluster
- Rancher management platform
- Security Scanning and Monitoring Tools

## Components

- **EKS Cluster**: Managed Kubernetes cluster on AWS
- **Control Tower**: AWS account structure and governance
- **Apache Kafka**: Distributed streaming platform
- **Rancher**: Kubernetes management platform
- **Prometheus & Grafana**: Monitoring and observability solution
    - Prometheus for metrics collection and storage
    - Grafana for metrics visualization and dashboarding
    - Deployed in the `monitoring` namespace
    - Grafana is exposed via LoadBalancer service
- **Security Scanning**:
    - Trivy Operator for container vulnerability scanning
    - AWS Secrets Manager for secure secrets storage
    - Pre-commit hooks for IaC security scanning
    - Terraform security scanning with Checkov and TFSec

## Prerequisites

- AWS Account
- Terraform >= 1.0
- AWS CLI configured
- kubectl installed
- Helm 3.x

## Quick Start

1. Clone this repository
2. Configure your AWS credentials
3. Create `terraform.tfvars` with your values
4. Create `secrets.tfvars` for sensitive values
5. Run Terraform:
   bash
# Initialize Terraform
terraform init
# Review changes
terraform plan -var-file="terraform.tfvars" -var-file="secrets.tfvars"
# Apply changes
terraform apply -var-file="terraform.tfvars" -var-file="secrets.tfvars"

## Security Best Practices
- Keep `secrets.tfvars` in `.gitignore`
- Use `terraform.tfvars.template` as a reference
- Rotate security scanning tokens regularly
- Review Trivy scan reports periodically
