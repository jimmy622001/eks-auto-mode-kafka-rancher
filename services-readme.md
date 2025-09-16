
### Rancher Management UI
- Access through configured hostname
- Default credentials:
    - Username: admin
    - Password: [specified in terraform.tfvars]

### Kafka
- Access through Kubernetes service
- Default port: 9092
- For external access, configure through Rancher UI

### Monitoring
- **Grafana Dashboard:**
  ```bash
  kubectl get svc -n monitoring grafana
  ```
    - Access through LoadBalancer URL
    - Default username: admin
    - Password: [specified in terraform.tfvars]

- **Prometheus:**
    - Accessed internally by Grafana
    - For direct access:
  ```bash
  kubectl port-forward -n monitoring svc/prometheus-server 9090:80
  ```

## Configuration Reference

### Required Variables
- `aws_region`: AWS region for deployment
- `cluster_name`: Name of the EKS cluster
- `environment`: Environment name (e.g., prod, dev)
- `rancher_admin_password`: Initial admin password for Rancher
- `grafana_admin_password`: Admin password for Grafana
- `organization_name`: AWS Organization name
- `organization_email`: Primary email for AWS Organization

### Optional Variables
- `vpc_cidr`: CIDR block for VPC (default: "10.20.0.0/19")
- `kubernetes_version`: EKS version
- `enable_guardrails`: Enable Control Tower guardrails (default: true)
- `enable_cloudtrail`: Enable CloudTrail logging (default: true)

## Maintenance

### Backup and Disaster Recovery
- EKS: Uses AWS managed control plane backup
- Kafka: Configured with replication for HA
- Monitoring: Persistent storage for metrics data

### Upgrading
1. Update version numbers in terraform.tfvars
2. Run terraform plan to review changes
3. Apply updates with terraform apply

### Monitoring and Logging
- Prometheus metrics retention: 15 days
- Grafana dashboards: Auto-configured for key metrics
- CloudWatch integration for AWS service logs

## Security

- EKS cluster: Private networking
- Control Tower: Security guardrails
- Rancher: RBAC enabled
- Kafka: Authentication required
- Monitoring: Secured access

## Support and Contribution

- Report issues through GitHub Issues
- Submit contributions via Pull Requests
- Follow coding and commit message conventions

## License

See LICENSE file for full details.