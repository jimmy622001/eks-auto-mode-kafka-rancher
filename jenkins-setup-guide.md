# Jenkins CI/CD with Cost Optimization on AWS

This guide explains how to deploy and use the cost-optimized Jenkins infrastructure that has been added to your EKS project.

## Overview

The Jenkins module provides a highly cost-effective CI/CD solution with the following features:

### 🚀 **Key Features**
- **Spot Instance Agents**: Up to 90% cost savings using EC2 Spot Instances
- **Auto-scaling**: Agents scale from 0 to N based on build demand
- **Auto-shutdown**: Master instance automatically stops during off-hours
- **Lambda Triggers**: Multiple trigger mechanisms (S3, GitHub, API Gateway)
- **S3 Integration**: Artifact storage and build triggers
- **GitHub Integration**: Webhook support and repository integration
- **Cost Monitoring**: Real-time cost tracking and optimization recommendations

### 💰 **Cost Optimization**
- **Spot Instances**: Jenkins agents run on Spot Instances (up to 90% savings)
- **Auto-shutdown**: Master instance stops at 10 PM and starts at 8 AM (configurable)
- **On-demand Scaling**: Agents only run when builds are active
- **Idle Termination**: Agents automatically terminate after 30 minutes of inactivity
- **Cost Reporting**: Automated cost tracking and S3 logging

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  Lambda Trigger  │───▶│ Jenkins Master  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐             │
│   S3 Triggers   │───▶│  Lambda Trigger  │             │
└─────────────────┘    └──────────────────┘             │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  EventBridge    │───▶│ Cost Optimizer   │    │ Auto Scaling    │
│   Schedules     │    │    Lambda        │    │ Group (Agents)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                                              ┌─────────────────┐
                                              │ Spot Instance   │
                                              │ Jenkins Agents  │
                                              └─────────────────┘
```

## Deployment

### Prerequisites

1. **SSH Key Pair**: Generate an SSH key pair for Jenkins instances
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/jenkins-key
```

2. **GitHub Token**: Create a GitHub Personal Access Token with repo permissions

3. **Required Variables**: Add these to your `terraform.tfvars`:

```hcl
# Jenkins Configuration
jenkins_admin_password = "your-secure-password"
jenkins_public_key     = "ssh-rsa AAAAB3NzaC1yc2E..." # Your public key content
github_token          = "ghp_your_github_token"
github_webhook_secret = "your-webhook-secret"

# Optional: Instance Configuration
jenkins_master_instance_type = "t3.medium"  # Default
jenkins_agent_instance_type  = "t3.large"   # Default
max_jenkins_agents           = 5             # Default
spot_max_price              = "0.10"        # Default

# Optional: Cost Optimization
enable_jenkins_auto_shutdown = true                    # Default
jenkins_shutdown_schedule   = "0 22 * * MON-FRI"     # 10 PM UTC
jenkins_startup_schedule    = "0 8 * * MON-FRI"      # 8 AM UTC

# Optional: Load Balancer
enable_jenkins_alb = false  # Set to true if you want ALB

# Optional: Notifications
slack_webhook_url  = "https://hooks.slack.com/..."
notification_email = "your-email@example.com"
```

### Deploy

```bash
terraform plan
terraform apply
```

## Usage

### Accessing Jenkins

After deployment, Jenkins will be available at:
- **Direct Access**: `http://<jenkins-private-ip>:8080` (from within VPC)
- **ALB Access**: `http://<alb-dns-name>` (if ALB is enabled)

**Default Credentials:**
- Username: `admin`
- Password: The value you set in `jenkins_admin_password`

### Triggering Builds

#### 1. **GitHub Webhooks** (Recommended)
Configure GitHub webhooks to point to your Lambda trigger function:

```bash
# Get the Lambda function URL from Terraform output
terraform output jenkins_lambda_trigger_arn

# Configure webhook in GitHub repository settings:
# Payload URL: https://your-api-gateway-url/trigger
# Content type: application/json
# Events: Push events
```

#### 2. **S3 Upload Triggers**
Upload a trigger file to S3 to start a build:

```bash
# Create a trigger file
echo '{"job_name": "github-pipeline", "branch": "main", "agent_count": 2}' > build.trigger

# Upload to S3 (this will automatically trigger a build)
aws s3 cp build.trigger s3://your-jenkins-artifacts-bucket/triggers/build.trigger
```

#### 3. **Manual API Triggers**
Use the Lambda function directly:

```bash
aws lambda invoke \
  --function-name your-jenkins-trigger-function \
  --payload '{"job_name": "github-pipeline", "branch": "main"}' \
  response.json
```

### Cost Management

#### Monitor Costs
```bash
# View cost optimization metrics
aws cloudwatch get-metric-statistics \
  --namespace "Jenkins/CostOptimization" \
  --metric-name "MasterInstanceStopped" \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

#### Manual Cost Controls
```bash
# Manually shutdown Jenkins (outside of schedule)
aws lambda invoke \
  --function-name your-jenkins-cost-optimizer-function \
  --payload '{"action": "shutdown"}' \
  response.json

# Manually startup Jenkins
aws lambda invoke \
  --function-name your-jenkins-cost-optimizer-function \
  --payload '{"action": "startup"}' \
  response.json

# Scale agents manually
aws lambda invoke \
  --function-name your-jenkins-cost-optimizer-function \
  --payload '{"action": "scale_agents", "desired_capacity": 3}' \
  response.json

# Generate cost report
aws lambda invoke \
  --function-name your-jenkins-cost-optimizer-function \
  --payload '{"action": "cost_report"}' \
  response.json
```

## Pipeline Configuration

### Sample Jenkinsfile

Create a `Jenkinsfile` in your repository:

```groovy
pipeline {
    agent {
        label 'spot-agent'
    }
    
    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    environment {
        AWS_REGION = 'us-west-2'
        S3_BUCKET = credentials('s3-bucket')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Building ${env.BRANCH_NAME} - ${env.BUILD_NUMBER}"
            }
        }
        
        stage('Build') {
            steps {
                script {
                    if (fileExists('package.json')) {
                        sh 'npm install'
                        sh 'npm run build'
                    } else if (fileExists('pom.xml')) {
                        sh 'mvn clean compile'
                    } else if (fileExists('Dockerfile')) {
                        sh 'docker build -t myapp:${BUILD_NUMBER} .'
                    }
                }
            }
        }
        
        stage('Test') {
            steps {
                script {
                    if (fileExists('package.json')) {
                        sh 'npm test'
                    } else if (fileExists('pom.xml')) {
                        sh 'mvn test'
                    }
                }
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                echo 'Deploying to production...'
                // Add your deployment steps here
                sh '''
                    echo "Deployment completed at $(date)"
                    aws s3 cp deployment-log.txt s3://$S3_BUCKET/deployments/
                '''
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline succeeded!'
            // Optional: Send Slack notification
        }
        failure {
            echo 'Pipeline failed!'
            // Optional: Send Slack notification
        }
    }
}
```

## Cost Estimates

### Typical Monthly Costs (us-west-2)

**Traditional Setup (Always On):**
- Jenkins Master (t3.medium): ~$30/month
- 2 Agents (t3.large): ~$120/month
- **Total: ~$150/month**

**Optimized Setup (This Solution):**
- Jenkins Master (16h/day): ~$15/month
- Spot Agents (2h/day average): ~$12/month
- Lambda executions: ~$1/month
- **Total: ~$28/month**

**💰 Savings: ~$122/month (81% reduction)**

### Cost Breakdown by Feature
- **Auto-shutdown**: 50% savings on master instance
- **Spot instances**: 70-90% savings on agent instances  
- **Auto-scaling**: 80-95% savings (agents only run when needed)
- **Idle termination**: Additional 10-20% savings

## Monitoring and Troubleshooting

### CloudWatch Metrics
- `Jenkins/CostOptimization/MasterInstanceStopped`
- `Jenkins/CostOptimization/MasterInstanceStarted`
- `Jenkins/CostOptimization/AgentsScaled`

### Logs
- Jenkins Master: `/var/log/jenkins/jenkins.log`
- Jenkins Agents: `/var/log/jenkins-*.log`
- Lambda Functions: CloudWatch Logs
- Cost Reports: S3 bucket under `cost-reports/`

### Common Issues

#### Jenkins Master Won't Start
```bash
# Check instance status
aws ec2 describe-instances --instance-ids i-your-instance-id

# Check system logs
aws logs get-log-events --log-group-name /aws/ec2/jenkins
```

#### Agents Not Connecting
```bash
# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names your-asg-name

# Check agent logs
ssh -i ~/.ssh/jenkins-key ec2-user@agent-ip
sudo journalctl -u jenkins-agent -f
```

#### Spot Instance Interruptions
Spot instances may be interrupted. The system handles this gracefully:
- Workspaces are backed up to S3
- New agents are automatically launched
- Builds are retried on new agents

## Security Considerations

### Network Security
- Jenkins master runs in private subnets
- Security groups restrict access to necessary ports only
- ALB provides controlled external access (if enabled)

### Secrets Management
- Jenkins passwords stored in SSM Parameter Store
- GitHub tokens encrypted in SSM
- IAM roles follow least-privilege principle

### Best Practices
1. Regularly rotate Jenkins admin password
2. Use GitHub App tokens instead of personal tokens
3. Enable Jenkins security plugins
4. Monitor access logs
5. Keep Jenkins and plugins updated

## Customization

### Modify Schedules
Update the cron expressions in `terraform.tfvars`:
```hcl
jenkins_shutdown_schedule = "0 20 * * MON-FRI"  # 8 PM shutdown
jenkins_startup_schedule  = "0 7 * * MON-FRI"   # 7 AM startup
```

### Add More Instance Types
Modify the launch template to support multiple instance types:
```hcl
# In modules/jenkins/main.tf
override {
  instance_type     = "t3.large"
  weighted_capacity = "1"
}
override {
  instance_type     = "t3.xlarge"
  weighted_capacity = "2"
}
```

### Custom Plugins
Add plugins to the user data script in `modules/jenkins/user_data/jenkins_master.sh`:
```bash
download_plugin "your-plugin-name" "version"
```

## Support and Maintenance

### Regular Maintenance
1. **Weekly**: Review cost reports and optimize
2. **Monthly**: Update Jenkins and plugins
3. **Quarterly**: Review and adjust instance types and schedules

### Backup Strategy
- Jenkins configuration: Automatically backed up to S3
- Build artifacts: Stored in S3 with versioning
- Workspaces: Backed up during spot interruptions

### Scaling Considerations
- Increase `max_jenkins_agents` for larger teams
- Consider larger instance types for resource-intensive builds
- Monitor queue times and adjust accordingly

---

## Quick Start Checklist

- [ ] Generate SSH key pair
- [ ] Create GitHub personal access token
- [ ] Update `terraform.tfvars` with required variables
- [ ] Run `terraform apply`
- [ ] Access Jenkins web interface
- [ ] Configure GitHub webhooks
- [ ] Create your first pipeline
- [ ] Monitor costs in CloudWatch

**🎉 You now have a cost-optimized Jenkins CI/CD pipeline that can save you 80%+ on infrastructure costs!**
