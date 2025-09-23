#!/bin/bash

# Jenkins Agent Installation Script for Spot Instances
# This script configures Jenkins agents with cost optimization features

set -e

# Variables from Terraform
JENKINS_MASTER_URL="${jenkins_master_url}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"

# Update system
yum update -y

# Install required packages
yum install -y wget curl git docker java-11-openjdk-devel unzip

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# Install Node.js (for modern web applications)
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install Python 3 and pip
yum install -y python3 python3-pip

# Install common build tools
yum groupinstall -y "Development Tools"
yum install -y maven gradle

# Create Jenkins user and workspace
useradd -m -s /bin/bash jenkins
mkdir -p /home/jenkins/workspace
chown -R jenkins:jenkins /home/jenkins

# Create Jenkins agent directory
mkdir -p /opt/jenkins
cd /opt/jenkins

# Download Jenkins agent JAR
wget $${JENKINS_MASTER_URL}/jnlpJars/agent.jar -O agent.jar
chown jenkins:jenkins agent.jar

# Create Jenkins agent service script
cat > /opt/jenkins/jenkins-agent.sh << 'EOF'
#!/bin/bash

# Jenkins Agent Service Script
set -e

JENKINS_MASTER_URL="$${JENKINS_MASTER_URL}"
AGENT_NAME=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AGENT_SECRET=""
JENKINS_USER="admin"
JENKINS_PASSWORD=""

# Function to get Jenkins credentials from SSM
get_jenkins_credentials() {
    JENKINS_PASSWORD=$(aws ssm get-parameter --region $${AWS_REGION} --name "/jenkins/*/admin-password" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
}

# Function to register agent with Jenkins master
register_agent() {
    echo "Registering agent with Jenkins master..."
    
    # Get Jenkins crumb for CSRF protection
    CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_MASTER_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" 2>/dev/null || echo "")
    
    # Create agent configuration
    AGENT_CONFIG='<slave>
        <name>'$AGENT_NAME'</name>
        <description>Spot Instance Jenkins Agent</description>
        <remoteFS>/home/jenkins</remoteFS>
        <numExecutors>2</numExecutors>
        <mode>NORMAL</mode>
        <retentionStrategy class="hudson.slaves.RetentionStrategy$Always"/>
        <launcher class="hudson.slaves.JNLPLauncher">
            <workDirSettings>
                <disabled>false</disabled>
                <workDirPath>/home/jenkins</workDirPath>
                <internalDir>remoting</internalDir>
                <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
            </workDirSettings>
        </launcher>
        <label>spot-agent linux docker</label>
        <nodeProperties/>
    </slave>'
    
    # Register the agent
    if [ ! -z "$CRUMB" ]; then
        curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
            -H "$CRUMB" \
            -H "Content-Type: application/xml" \
            -d "$AGENT_CONFIG" \
            "$JENKINS_MASTER_URL/computer/doCreateItem?name=$AGENT_NAME&type=hudson.slaves.DumbSlave" || true
    fi
    
    # Get agent secret
    AGENT_SECRET=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_MASTER_URL/computer/$AGENT_NAME/slave-agent.jnlp" | grep -oP 'application-desc.*?<argument>\K[^<]*' | head -1 || echo "")
}

# Function to start Jenkins agent
start_agent() {
    echo "Starting Jenkins agent..."
    
    if [ -z "$AGENT_SECRET" ]; then
        echo "Warning: No agent secret found, attempting to connect anyway..."
        java -jar /opt/jenkins/agent.jar -jnlpUrl "$JENKINS_MASTER_URL/computer/$AGENT_NAME/slave-agent.jnlp" -workDir /home/jenkins
    else
        java -jar /opt/jenkins/agent.jar -jnlpUrl "$JENKINS_MASTER_URL/computer/$AGENT_NAME/slave-agent.jnlp" -secret "$AGENT_SECRET" -workDir /home/jenkins
    fi
}

# Function to handle spot instance interruption
handle_interruption() {
    echo "Spot instance interruption detected, gracefully shutting down..."
    
    # Notify Jenkins master that agent is going offline
    if [ ! -z "$JENKINS_PASSWORD" ] && [ ! -z "$AGENT_NAME" ]; then
        CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_MASTER_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" 2>/dev/null || echo "")
        if [ ! -z "$CRUMB" ]; then
            curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
                -H "$CRUMB" \
                "$JENKINS_MASTER_URL/computer/$AGENT_NAME/doDisconnect" || true
        fi
    fi
    
    # Upload any remaining artifacts to S3
    if [ -d "/home/jenkins/workspace" ]; then
        echo "Uploading workspace artifacts to S3..."
        aws s3 sync /home/jenkins/workspace s3://$${S3_BUCKET}/agent-workspaces/$AGENT_NAME/ --delete || true
    fi
    
    exit 0
}

# Set up signal handlers for graceful shutdown
trap handle_interruption SIGTERM SIGINT

# Main execution
echo "Starting Jenkins agent setup..."
echo "Agent Name: $AGENT_NAME"
echo "Jenkins Master URL: $JENKINS_MASTER_URL"

# Get credentials
get_jenkins_credentials

# Wait for Jenkins master to be available
echo "Waiting for Jenkins master to be available..."
for i in {1..30}; do
    if curl -s -f "$JENKINS_MASTER_URL/login" > /dev/null 2>&1; then
        echo "Jenkins master is available"
        break
    fi
    echo "Attempt $i: Jenkins master not ready, waiting 30 seconds..."
    sleep 30
done

# Register and start agent
register_agent
start_agent
EOF

chmod +x /opt/jenkins/jenkins-agent.sh
chown jenkins:jenkins /opt/jenkins/jenkins-agent.sh

# Create systemd service for Jenkins agent
cat > /etc/systemd/system/jenkins-agent.service << EOF
[Unit]
Description=Jenkins Agent
After=network.target

[Service]
Type=simple
User=jenkins
Group=jenkins
WorkingDirectory=/opt/jenkins
ExecStart=/opt/jenkins/jenkins-agent.sh
Restart=always
RestartSec=30
Environment="JENKINS_MASTER_URL=$${JENKINS_MASTER_URL}"
Environment="S3_BUCKET=$${S3_BUCKET}"
Environment="AWS_REGION=$${AWS_REGION}"

[Install]
WantedBy=multi-user.target
EOF

# Create spot instance interruption handler
cat > /opt/jenkins/spot-interruption-handler.sh << 'EOF'
#!/bin/bash

# Spot Instance Interruption Handler
# This script monitors for spot instance interruption notices

METADATA_URL="http://169.254.169.254/latest/meta-data"
INTERRUPTION_URL="$METADATA_URL/spot/instance-action"

while true; do
    # Check for spot instance interruption notice
    HTTP_CODE=$(curl -s -o /dev/null -w "%%{http_code}" "$INTERRUPTION_URL" --max-time 2)
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "$(date): Spot instance interruption notice received"
        
        # Get interruption details
        INTERRUPTION_TIME=$(curl -s "$INTERRUPTION_URL" | jq -r '.time' 2>/dev/null || echo "unknown")
        echo "$(date): Interruption scheduled for: $INTERRUPTION_TIME"
        
        # Trigger graceful shutdown of Jenkins agent
        systemctl stop jenkins-agent
        
        # Upload final logs and artifacts
        if [ -d "/home/jenkins/workspace" ]; then
            INSTANCE_ID=$(curl -s "$METADATA_URL/instance-id")
            aws s3 sync /home/jenkins/workspace "s3://$${S3_BUCKET}/interrupted-workspaces/$INSTANCE_ID/" || true
        fi
        
        # Log the interruption
        echo "$(date): Spot instance interruption handled gracefully" | aws logs put-log-events \
            --log-group-name "/aws/ec2/jenkins-agents" \
            --log-stream-name "$(curl -s $METADATA_URL/instance-id)" \
            --log-events timestamp=$(date +%s000),message="Spot instance interruption handled gracefully" || true
        
        break
    fi
    
    # Check every 5 seconds
    sleep 5
done
EOF

chmod +x /opt/jenkins/spot-interruption-handler.sh

# Create systemd service for spot interruption handler
cat > /etc/systemd/system/spot-interruption-handler.service << EOF
[Unit]
Description=Spot Instance Interruption Handler
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/jenkins/spot-interruption-handler.sh
Restart=always
RestartSec=10
Environment="S3_BUCKET=$${S3_BUCKET}"
Environment="AWS_REGION=$${AWS_REGION}"

[Install]
WantedBy=multi-user.target
EOF

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install kubectl for Kubernetes deployments
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform (for infrastructure as code builds)
yum install -y yum-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum install -y terraform

# Create workspace cleanup script
cat > /opt/jenkins/cleanup-workspace.sh << 'EOF'
#!/bin/bash

# Jenkins Agent Workspace Cleanup Script
# This script cleans up old workspaces to save disk space

WORKSPACE_DIR="/home/jenkins/workspace"
MAX_AGE_DAYS=7

if [ -d "$WORKSPACE_DIR" ]; then
    echo "$(date): Cleaning up workspaces older than $MAX_AGE_DAYS days..."
    
    # Find and remove old workspace directories
    find "$WORKSPACE_DIR" -type d -mtime +$MAX_AGE_DAYS -exec rm -rf {} + 2>/dev/null || true
    
    # Clean up Docker images and containers
    docker system prune -f --volumes || true
    
    # Clean up old build artifacts
    find /tmp -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
    
    echo "$(date): Workspace cleanup completed"
fi
EOF

chmod +x /opt/jenkins/cleanup-workspace.sh

# Create cron job for workspace cleanup
echo "0 2 * * * jenkins /opt/jenkins/cleanup-workspace.sh >> /var/log/jenkins-cleanup.log 2>&1" >> /etc/crontab

# Create cost monitoring script
cat > /opt/jenkins/cost-monitor.sh << 'EOF'
#!/bin/bash

# Jenkins Agent Cost Monitoring Script
# This script monitors agent usage and reports cost metrics

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$${AVAILABILITY_ZONE%?}

# Get current spot price
SPOT_PRICE=$(aws ec2 describe-spot-price-history \
    --region $REGION \
    --instance-types $INSTANCE_TYPE \
    --product-descriptions "Linux/UNIX" \
    --max-items 1 \
    --query 'SpotPriceHistory[0].SpotPrice' \
    --output text 2>/dev/null || echo "0.00")

# Calculate uptime
UPTIME_SECONDS=$(awk '{print int($1)}' /proc/uptime)
UPTIME_HOURS=$(echo "scale=2; $UPTIME_SECONDS / 3600" | bc -l)

# Estimate cost
ESTIMATED_COST=$(echo "scale=4; $SPOT_PRICE * $UPTIME_HOURS" | bc -l)

# Create cost report
COST_REPORT="{
    \"timestamp\": \"$(date -Iseconds)\",
    \"instance_id\": \"$INSTANCE_ID\",
    \"instance_type\": \"$INSTANCE_TYPE\",
    \"availability_zone\": \"$AVAILABILITY_ZONE\",
    \"spot_price\": \"$SPOT_PRICE\",
    \"uptime_hours\": \"$UPTIME_HOURS\",
    \"estimated_cost\": \"$ESTIMATED_COST\",
    \"cpu_usage\": \"$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)\",
    \"memory_usage\": \"$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')\",
    \"disk_usage\": \"$(df -h / | awk 'NR==2{printf "%s", $5}')\",
    \"active_builds\": \"$(pgrep -f jenkins | wc -l)\"
}"

# Upload cost report to S3
echo "$COST_REPORT" > /tmp/agent-cost-report.json
aws s3 cp /tmp/agent-cost-report.json "s3://$${S3_BUCKET}/cost-reports/agents/$(date +%Y%m%d)/agent-$INSTANCE_ID-$(date +%H%M%S).json" || true
rm -f /tmp/agent-cost-report.json

echo "Cost report uploaded: Estimated cost \$$ESTIMATED_COST for $UPTIME_HOURS hours"
EOF

chmod +x /opt/jenkins/cost-monitor.sh

# Create cron job for cost monitoring (every 15 minutes)
echo "*/15 * * * * jenkins /opt/jenkins/cost-monitor.sh >> /var/log/jenkins-cost-monitor.log 2>&1" >> /etc/crontab

# Set up log rotation
cat > /etc/logrotate.d/jenkins-agent << EOF
/var/log/jenkins-*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 jenkins jenkins
}
EOF

# Create CloudWatch agent configuration
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "metrics": {
        "namespace": "Jenkins/Agents",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 300,
                "totalcpu": true
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 300,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 300
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 300
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/jenkins-*.log",
                        "log_group_name": "/aws/ec2/jenkins-agents",
                        "log_stream_name": "{instance_id}/jenkins-agent.log"
                    }
                ]
            }
        }
    }
}
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable jenkins-agent
systemctl enable spot-interruption-handler

# Start services
systemctl start spot-interruption-handler
systemctl start jenkins-agent

# Final setup
echo "Jenkins agent installation completed!"
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
echo "Jenkins Master URL: $${JENKINS_MASTER_URL}"
echo "Agent will automatically register with Jenkins master"

# Log successful startup
echo "$(date): Jenkins agent startup completed" >> /var/log/jenkins-agent-startup.log
