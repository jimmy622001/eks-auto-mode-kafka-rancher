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

## Project Structure

```
.
├── modules/               # Reusable Terraform modules
├── workspaces/
│   ├── dev/               # Development environment
│   │   ├── dev.tfvars.example  # Example configuration (versioned)
│   │   └── terraform.tfvars    # Actual configuration (gitignored)
│   └── prod/              # Production environment
│       ├── prod.tfvars.example # Example configuration (versioned)
│       └── terraform.tfvars    # Actual configuration (gitignored)
├── terraform-bootstrap.tf # Bootstrap resources (S3, etc.)
└── main.tf               # Root module configuration
```

## Prerequisites

- AWS Account with appropriate IAM permissions
- Terraform >= 1.0
- AWS CLI configured with credentials
- kubectl installed
- Helm 3.x
- jq (for some deployment scripts)

## Environment Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd eks-auto-mode-kafka-rancher
   ```

2. **Set up your environment** (choose one):

   ### Development Environment
   ```bash
   cd workspaces/dev
   cp dev.tfvars.example terraform.tfvars
   ```
   
   ### Production Environment
   ```bash
   cd workspaces/prod
   cp prod.tfvars.example terraform.tfvars
   ```

3. **Edit the configuration**:
   - Update `terraform.tfvars` with your specific values
   - Change all default passwords and sensitive values
   - Update the `aws_region` if needed (default: eu-west-1)

## Deployment

### 1. Bootstrap (First Time Only)

```bash
# From repository root
cd workspaces/<env>  # dev or prod

# Initialize Terraform with backend configuration
terraform init -backend-config="../backend.hcl"

# Initialize the S3 bucket for Terraform state (first time only)
cd ../..
terraform -chdir=terraform-bootstrap init
terraform -chdir=terraform-bootstrap apply
```

### 2. Deploy Infrastructure

```bash
# From the environment directory (workspaces/dev or workspaces/prod)
cd workspaces/<env>

# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration (type 'yes' to confirm)
terraform apply
```

### 3. Access the Environment

After successful deployment, you can access:

- **Rancher Dashboard**: `https://<rancher_hostname>`
- **Grafana**: `http://<loadbalancer-address>` (check output for exact URL)
- **Kubernetes Cluster**:
  ```bash
  aws eks --region <region> update-kubeconfig --name <cluster-name>
  kubectl get nodes
  ```

## Managing the Environment

### Update Configuration
1. Edit `terraform.tfvars` in your environment directory
2. Run `terraform plan` to review changes
3. Apply with `terraform apply`

### Destroy Environment

⚠️ **Warning**: This will permanently delete all resources!

```bash
# From the environment directory
terraform destroy
```

## Security Best Practices

- Never commit `terraform.tfvars` to version control
- Use strong, unique passwords for all services
- Regularly rotate credentials and access keys
- Enable MFA for all IAM users
- Review CloudTrail logs for suspicious activity
- Keep Terraform and providers updated

## Troubleshooting

- **Authentication Issues**: Verify AWS credentials and region
- **Module Errors**: Run `terraform init -upgrade`
- **Kubernetes Access**: Verify your kubeconfig is up to date
- **Resource Limits**: Check AWS service quotas if resources fail to create

## Security Best Practices
- Keep `secrets.tfvars` in `.gitignore`
- Use `terraform.tfvars.template` as a reference
- Rotate security scanning tokens regularly
- Review Trivy scan reports periodically

![alt text](image.png)