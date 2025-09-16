
# EKS Auto-Mode with Kafka and Rancher

This project provides Infrastructure as Code (IaC) for deploying a production-ready EKS cluster with integrated services including Apache Kafka, Rancher management platform, and monitoring solutions.

## Architecture Components

### Core Infrastructure
- **AWS Control Tower Landing Zone**
  - Multi-account AWS environment
  - Centralized logging and security
  - Compliance and governance guardrails
  - Automated account provisioning

- **Amazon EKS Cluster**
  - Managed Kubernetes service
  - Auto-scaling node groups
  - Private networking configuration
  - IAM integration

### Management Layer
- **Rancher Management Platform**
  - Multi-cluster management
  - RBAC configuration
  - GitOps integration
  - Unified cluster operations

### Data Services
- **Apache Kafka Cluster**
  - Distributed streaming platform
  - High availability configuration
  - Auto-scaling capabilities
  - Monitoring integration

### Monitoring Stack
- **Prometheus & Grafana**
  - Prometheus for metrics collection and storage
  - Grafana for metrics visualization and dashboarding
  - Pre-configured dashboards for Kubernetes and Kafka
  - Persistent storage for metrics data

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

## Prerequisites

- AWS Account
- Terraform >= 1.0
- AWS CLI configured
- kubectl installed
- Helm 3.x
- Domain name for Rancher access (optional)

## Quick Start

1. Clone the repository:
2.
# EKS Auto-Mode with Kafka and Rancher

This project provides Infrastructure as Code (IaC) for deploying:
- Amazon EKS cluster
- AWS Control Tower Landing Zone
- Apache Kafka cluster
- Rancher management platform

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

## Prerequisites

- AWS Account
- Terraform >= 1.0
- AWS CLI configured
- kubectl installed
- Helm 3.x

## Quick Start

1. Clone this repository
2. Configure your AWS credentials
3. Update `terraform.tfvars` with your values
4. Run: