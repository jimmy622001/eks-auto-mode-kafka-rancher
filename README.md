# EKS Auto-Mode with Kafka and Rancher POC

This project provides **Infrastructure as Code (IaC)** to deploy a robust, scalable, and secure infrastructure using:
- **Amazon EKS** for container orchestration
- **AWS Control Tower** for multi-account governance
- **Apache Kafka** for distributed messaging and streaming
- **Rancher** for Kubernetes management
- **Prometheus & Grafana** for monitoring and observability
- **Security Scanning Tools** for enhanced compliance and platform safety

## **Executive Summary**
This solution architecture is designed to:
- **Enable scalability and resilience** through managed cloud-native platforms like AWS EKS and Kafka.
- **Simplify Kubernetes cluster management** using Rancher, with role-based access control (RBAC).
- **Ensure observability** with Prometheus and Grafana for monitoring and dashboarding.
- **Address security and compliance concerns** via tools like Trivy, AWS Secrets Manager, and Terraform scanning.
- **Reduce operational complexity** by leveraging Terraform modules for infrastructure provisioning.

Key benefits include:
1. Improved **system availability** with multi-AZ deployments.
2. Secured Kubernetes workloads through strong IAM policies and secrets management.
3. Rapid deployment cycle with the use of Infrastructure-as-Code (IaC).

---

## **Solution Components**
| Component            | Description                                                                                                                                      |
|-----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| **Amazon EKS**        | Managed Kubernetes service for running containerized workloads at scale.                                                                         |
| **AWS Control Tower** | Provides governance for multi-account AWS environments and centralized logging/auditing.                                                        |
| **Apache Kafka**      | Distributed messaging platform for streaming and event processing.                                                                               |
| **Rancher**           | Kubernetes management tool for multi-cluster management and RBAC configuration.                                                                 |
| **Prometheus**        | Collects and stores time-series metrics from Kubernetes workloads.                                                                               |
| **Grafana**           | Visualization platform for creating dashboards based on Prometheus metrics.                                                                     |
| **Security Tools**    | Trivy, Checkov, TFSec, and AWS Secrets Manager ensure container and IaC security compliance through automated vulnerability and configuration scanning. |

---

## **Solution Architecture**
### **Conceptual View**
This architecture focuses on high availability, security, and observability across cloud-native technologies:
1. **EKS** serves as the foundation for containerized workloads, offering managed scaling and integration with other AWS services.
2. **Kafka** provides horizontally scalable message queues, ideal for real-time event streaming.
3. **Security scanning** ensures workloads are hardened against vulnerabilities, while IAM provides role-based access control across AWS resources.
4. **Monitoring with Prometheus** ensures system health and performance visibility.

---

## **Setup and Deployment**
### **Prerequisites**
Before setting up the environment, ensure the following are installed and configured on your local machine:
- **AWS Account**: Ensure appropriate IAM role permissions.
- **Required Tools**:
  - Terraform `>= 1.0` 
  - AWS CLI configured with credentials.
  - `kubectl`  installed and configured.
  - `Helm 3.x` 
  - `jq`  (required by deployment scripts)

---

### **Environment Setup**
1. **Clone the Repository:**
   ```bash
   git clone <repository-url>
   cd eks-auto-mode-kafka-rancher

![alt text](image.png)
