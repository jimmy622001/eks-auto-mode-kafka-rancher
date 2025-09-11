
# EKS Cluster with Kafka and Rancher
Note: Comment out CDN and Kafka until EKS is running thereafter build the rest.

This Terraform project deploys a production-ready EKS cluster on AWS with Kafka and Rancher for monitoring. The infrastructure is set up in a modular way with high availability in mind.

## Infrastructure Components

### VPC Setup
- Creates a VPC with CIDR block 10.20.0.0/19
- 3 Availability Zones with public and private subnets
- NAT Gateway for private subnet internet access
- VPN Gateway enabled
- DNS hostnames and support enabled
- Proper tagging for EKS integration

### EKS Cluster
- Kubernetes version 1.32
- Private and public endpoint access
- Auto Scaling Features:
  - Cluster Autoscaler enabled for automatic node scaling
  - General purpose node group: 2-5 nodes
  - System node group: 2-3 nodes
  - Auto-scaling policies and IAM roles configured
- Load Balancing:
  - AWS Load Balancer Controller integration
  - Elastic Load Balancing enabled
  - Support for both internal and external load balancers
  - Automatic load balancer provisioning
- Node pools for general-purpose and system workloads
- Block storage support
- Zonal shift capability for high availability

### Security
- IAM roles and policies for EKS cluster and nodes
- Proper security group configurations
- API authentication mode
- Minimal node permissions
- Auto-scaling specific IAM permissions

### Applications

#### Kafka Deployment
- 3 replica deployment for high availability
- GP3 storage class for persistence
- Resource limits:
    - CPU: 2000m
    - Memory: 4Gi
- Resource requests:
    - CPU: 1000m
    - Memory: 2Gi

#### Rancher Deployment
- 3 replica deployment for high availability
- Cert-manager integration for TLS
- Web UI access via custom hostname
- Monitoring capabilities for the EKS cluster

## Prerequisites
- AWS CLI configured
- Terraform >= 1.0
- kubectl
- Helm v3

## Usage

1. Clone the repository
