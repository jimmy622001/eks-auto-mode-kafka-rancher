#!/bin/bash

# Jenkins Master Installation and Configuration Script
# This script installs Jenkins with cost optimization features

set -e

# Variables from Terraform
JENKINS_ADMIN_PASSWORD="${jenkins_admin_password}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
GITHUB_TOKEN="${github_token}"
GITHUB_WEBHOOK_SECRET="${github_webhook_secret}"

# Update system
yum update -y

# Install required packages
yum install -y wget curl git docker java-11-openjdk-devel

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y jenkins

# Configure Jenkins
mkdir -p /var/lib/jenkins
chown jenkins:jenkins /var/lib/jenkins

# Create Jenkins configuration
cat > /var/lib/jenkins/jenkins.install.UpgradeWizard.state << EOF
2.401.3
EOF

# Skip initial setup wizard
cat > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion << EOF
2.401.3
EOF

# Create admin user configuration
ADMIN_HASH=$(echo -n "admin" | sha256sum | cut -d' ' -f1)
mkdir -p /var/lib/jenkins/users/admin_$ADMIN_HASH
cat > /var/lib/jenkins/users/admin_$ADMIN_HASH/config.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<user>
  <version>10</version>
  <id>admin</id>
  <fullName>Administrator</fullName>
  <properties>
    <jenkins.security.ApiTokenProperty>
      <apiToken>
        <name>default</name>
        <value>{AQAAABAAAAAQqU+m+mC6ZnLa0+yaanj2eczT0JaMF5lTBjOzqHnn8hg=}</value>
        <creationDate>1609459200000</creationDate>
      </apiToken>
    </jenkins.security.ApiTokenProperty>
    <hudson.security.HudsonPrivateSecurityRealm_-Details>
      <passwordHash>#jbcrypt:\$2a\$10\$DdaWzN64JgUtLdvxWIflcuQu2fgrrMSAMabF5TSrGK5nXitqK9ZMS</passwordHash>
    </hudson.security.HudsonPrivateSecurityRealm_-Details>
  </properties>
</user>
EOF

# Set Jenkins admin password
JENKINS_HASH=$(echo -n "$JENKINS_ADMIN_PASSWORD" | sha256sum | cut -d' ' -f1)
sed -i "s/DdaWzN64JgUtLdvxWIflcuQu2fgrrMSAMabF5TSrGK5nXitqK9ZMS/$JENKINS_HASH/g" /var/lib/jenkins/users/admin_*/config.xml

# Create Jenkins security configuration
cat > /var/lib/jenkins/config.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<hudson>
  <version>2.401.3</version>
  <numExecutors>2</numExecutors>
  <mode>NORMAL</mode>
  <useSecurity>true</useSecurity>
  <authorizationStrategy class="hudson.security.FullControlOnceLoggedInAuthorizationStrategy">
    <denyAnonymousReadAccess>true</denyAnonymousReadAccess>
  </authorizationStrategy>
  <securityRealm class="hudson.security.HudsonPrivateSecurityRealm">
    <disableSignup>true</disableSignup>
    <enableCaptcha>false</enableCaptcha>
  </securityRealm>
  <disableRememberMe>false</disableRememberMe>
  <projectNamingStrategy class="jenkins.model.ProjectNamingStrategy$DefaultProjectNamingStrategy"/>
  <workspaceDir>$${JENKINS_HOME}/workspace/$${ITEM_FULLNAME}</workspaceDir>
  <buildsDir>$${ITEM_ROOTDIR}/builds</buildsDir>
  <markupFormatter class="hudson.markup.EscapedMarkupFormatter"/>
  <jdks/>
  <viewsTabBar class="hudson.views.DefaultViewsTabBar"/>
  <myViewsTabBar class="hudson.views.DefaultMyViewsTabBar"/>
  <clouds>
    <hudson.plugins.ec2.EC2Cloud plugin="ec2@1.72">
      <name>ec2-spot-cloud</name>
      <useInstanceProfileForCredentials>true</useInstanceProfileForCredentials>
      <credentialsId></credentialsId>
      <privateKey></privateKey>
      <instanceCap>5</instanceCap>
      <templates>
        <hudson.plugins.ec2.SlaveTemplate>
          <ami>ami-0abcdef1234567890</ami>
          <description>Jenkins Spot Agent</description>
          <zone>us-west-2a</zone>
          <securityGroups>jenkins-agents</securityGroups>
          <remoteFS>/home/ec2-user/jenkins</remoteFS>
          <type>T3Large</type>
          <ebsOptimized>false</ebsOptimized>
          <labels>spot-agent linux</labels>
          <mode>NORMAL</mode>
          <initScript>#!/bin/bash
yum update -y
yum install -y java-11-openjdk-devel git docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
</initScript>
          <tmpDir>/tmp</tmpDir>
          <userData></userData>
          <numExecutors>2</numExecutors>
          <remoteAdmin>ec2-user</remoteAdmin>
          <jvmopts></jvmopts>
          <stopOnTerminate>false</stopOnTerminate>
          <subnetId></subnetId>
          <tags>
            <hudson.plugins.ec2.EC2Tag>
              <name>Name</name>
              <value>jenkins-spot-agent</value>
            </hudson.plugins.ec2.EC2Tag>
            <hudson.plugins.ec2.EC2Tag>
              <name>Type</name>
              <value>jenkins-agent</value>
            </hudson.plugins.ec2.EC2Tag>
          </tags>
          <idleTerminationMinutes>30</idleTerminationMinutes>
          <usePrivateDnsName>true</usePrivateDnsName>
          <instanceCapStr>5</instanceCapStr>
          <iamInstanceProfile></iamInstanceProfile>
          <deleteRootOnTermination>true</deleteRootOnTermination>
          <useEphemeralDevices>false</useEphemeralDevices>
          <customDeviceMapping></customDeviceMapping>
          <installPrivateKey>true</installPrivateKey>
          <useSpotInstance>true</useSpotInstance>
          <spotConfig>
            <spotMaxBidPrice>0.10</spotMaxBidPrice>
            <spotBlockReservationDuration>0</spotBlockReservationDuration>
            <fallbackToOndemand>true</fallbackToOndemand>
          </spotConfig>
        </hudson.plugins.ec2.SlaveTemplate>
      </templates>
      <region>us-west-2</region>
    </hudson.plugins.ec2.EC2Cloud>
  </clouds>
  <quietPeriod>5</quietPeriod>
  <scmCheckoutRetryCount>0</scmCheckoutRetryCount>
  <views>
    <hudson.model.AllView>
      <owner class="hudson" reference="../../.."/>
      <name>all</name>
      <filterExecutors>false</filterExecutors>
      <filterQueue>false</filterQueue>
      <properties class="hudson.model.View$PropertyList"/>
    </hudson.model.AllView>
  </views>
  <primaryView>all</primaryView>
  <slaveAgentPort>50000</slaveAgentPort>
  <label></label>
  <crumbIssuer class="hudson.security.csrf.DefaultCrumbIssuer">
    <excludeClientIPFromCrumb>false</excludeClientIPFromCrumb>
  </crumbIssuer>
  <nodeProperties/>
  <globalNodeProperties/>
</hudson>
EOF

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Create Jenkins plugins directory and install essential plugins
mkdir -p /var/lib/jenkins/plugins

# Download essential plugins
PLUGIN_DIR="/var/lib/jenkins/plugins"
JENKINS_UC_DOWNLOAD="https://updates.jenkins.io/download"

# Function to download plugin
download_plugin() {
    local plugin_name=$1
    local plugin_version=$2
    echo "Downloading $plugin_name:$plugin_version"
    curl -L "$JENKINS_UC_DOWNLOAD/plugins/$plugin_name/$plugin_version/$plugin_name.hpi" -o "$PLUGIN_DIR/$plugin_name.jpi"
}

# Essential plugins for cost optimization and CI/CD
download_plugin "ec2" "1.72"
download_plugin "github" "1.37.3"
download_plugin "git" "4.13.0"
download_plugin "workflow-aggregator" "2.6"
download_plugin "pipeline-stage-view" "2.25"
download_plugin "blueocean" "1.25.8"
download_plugin "slack" "2.48"
download_plugin "build-timeout" "1.27"
download_plugin "timestamper" "1.17"
download_plugin "ws-cleanup" "0.45"
download_plugin "ant" "1.13"
download_plugin "gradle" "1.39.4"
download_plugin "nodejs" "1.5.1"
download_plugin "docker-workflow" "1.29"
download_plugin "amazon-ecr" "1.7"
download_plugin "s3" "0.12.0"

# Create Jenkins job for cost optimization monitoring
mkdir -p /var/lib/jenkins/jobs/cost-optimization-monitor/
cat > /var/lib/jenkins/jobs/cost-optimization-monitor/config.xml << 'JOBEOF'
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Monitor and optimize Jenkins infrastructure costs</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.plugins.buildblocker.BuildBlockerProperty plugin="build-blocker-plugin@1.7.8">
      <useBuildBlocker>false</useBuildBlocker>
      <blockLevel>GLOBAL</blockLevel>
      <scanQueueFor>DISABLED</scanQueueFor>
      <blockingJobs></blockingJobs>
    </hudson.plugins.buildblocker.BuildBlockerProperty>
  </properties>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers>
    <hudson.triggers.TimerTrigger>
      <spec>H/15 * * * *</spec>
    </hudson.triggers.TimerTrigger>
  </triggers>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>#!/bin/bash
# Cost optimization monitoring script
echo "=== Jenkins Cost Optimization Monitor ==="
echo "Timestamp: $(date)"

# Check for idle agents
echo "Checking for idle agents..."
IDLE_AGENTS=$(aws ec2 describe-instances --region $AWS_REGION \
  --filters "Name=tag:Type,Values=jenkins-agent" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[?LaunchTime <= `'$(date -d '30 minutes ago' -Iseconds)'`].[InstanceId,LaunchTime]' \
  --output text)

if [ ! -z "$IDLE_AGENTS" ]; then
  echo "Found potentially idle agents:"
  echo "$IDLE_AGENTS"
  # Terminate idle agents (this would be more sophisticated in production)
  # aws ec2 terminate-instances --instance-ids $IDLE_AGENTS
fi

# Check spot instance savings
echo "Checking spot instance usage..."
SPOT_SAVINGS=$(aws ec2 describe-spot-price-history --region $AWS_REGION \
  --instance-types t3.large --product-descriptions "Linux/UNIX" \
  --max-items 1 --query 'SpotPriceHistory[0].SpotPrice' --output text)

echo "Current spot price for t3.large: \$${SPOT_SAVINGS}/hour"

# Upload metrics to S3
echo "Uploading cost metrics to S3..."
echo "{\"timestamp\":\"$(date -Iseconds)\",\"spot_price\":\"$SPOT_SAVINGS\",\"idle_agents\":\"$IDLE_AGENTS\"}" > /tmp/cost-metrics.json
aws s3 cp /tmp/cost-metrics.json s3://$S3_BUCKET/metrics/cost-$(date +%Y%m%d-%H%M%S).json

echo "=== Cost optimization check complete ==="
</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers>
    <hudson.plugins.build__timeout.BuildTimeoutWrapper plugin="build-timeout@1.27">
      <strategy class="hudson.plugins.build__timeout.impl.AbsoluteTimeOutStrategy">
        <timeoutMinutes>5</timeoutMinutes>
      </strategy>
      <operationList>
        <hudson.plugins.build__timeout.operations.FailOperation/>
      </operationList>
    </hudson.plugins.build__timeout.BuildTimeoutWrapper>
  </buildWrappers>
</project>
JOBEOF

# Set proper ownership
chown -R jenkins:jenkins /var/lib/jenkins

# Create systemd override for Jenkins to set environment variables
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf << ENVEOF
[Service]
Environment="AWS_REGION=$AWS_REGION"
Environment="S3_BUCKET=$S3_BUCKET"
Environment="GITHUB_TOKEN=$GITHUB_TOKEN"
ENVEOF

# Start and enable Jenkins
systemctl daemon-reload
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 60

# Create a simple pipeline job for GitHub integration
mkdir -p /var/lib/jenkins/jobs/github-pipeline/
cat > /var/lib/jenkins/jobs/github-pipeline/config.xml << 'PIPELINEEOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.42">
  <actions/>
  <description>Pipeline triggered by GitHub webhooks</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <com.cloudbees.jenkins.GitHubPushTrigger plugin="github@1.37.3">
          <spec></spec>
        </com.cloudbees.jenkins.GitHubPushTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.92">
    <script>pipeline {
    agent {
        label 'spot-agent'
    }
    
    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    environment {
        AWS_REGION = credentials('aws-region')
        S3_BUCKET = credentials('s3-bucket')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Checked out code from GitHub"
            }
        }
        
        stage('Build') {
            steps {
                echo "Building application..."
                // Add your build steps here
                sh 'echo "Build completed at $(date)"'
            }
        }
        
        stage('Test') {
            steps {
                echo "Running tests..."
                // Add your test steps here
                sh 'echo "Tests completed at $(date)"'
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                echo "Deploying to production..."
                // Add your deployment steps here
                sh 'echo "Deployment completed at $(date)"'
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                echo "Archiving artifacts to S3..."
                sh '''
                    echo "Build artifacts" > build-artifact.txt
                    aws s3 cp build-artifact.txt s3://$S3_BUCKET/artifacts/build-$${BUILD_NUMBER}-$(date +%Y%m%d-%H%M%S).txt
                '''
            }
        }
    }
    
    post {
        always {
            echo "Pipeline completed"
            cleanWs()
        }
        success {
            echo "Pipeline succeeded!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
PIPELINEEOF

# Set ownership again after creating jobs
chown -R jenkins:jenkins /var/lib/jenkins

# Restart Jenkins to load new configuration
systemctl restart jenkins

# Create a script for cost optimization
cat > /usr/local/bin/jenkins-cost-optimizer.sh << 'SCRIPTEOF'
#!/bin/bash

# Jenkins Cost Optimization Script
# This script manages Jenkins infrastructure costs

AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

case "$1" in
    "shutdown")
        echo "Shutting down Jenkins master for cost optimization..."
        # Stop Jenkins service
        systemctl stop jenkins
        # Stop the instance
        aws ec2 stop-instances --region $AWS_REGION --instance-ids $INSTANCE_ID
        ;;
    "startup")
        echo "Starting Jenkins master..."
        # Start Jenkins service (instance should already be running)
        systemctl start jenkins
        ;;
    "scale-agents")
        DESIRED_CAPACITY=$${2:-0}
        echo "Scaling Jenkins agents to $DESIRED_CAPACITY..."
        ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --region $AWS_REGION \
            --query 'AutoScalingGroups[?contains(Tags[?Key==`Name`].Value, `jenkins-agent`)].AutoScalingGroupName' \
            --output text)
        if [ ! -z "$ASG_NAME" ]; then
            aws autoscaling set-desired-capacity --region $AWS_REGION \
                --auto-scaling-group-name $ASG_NAME \
                --desired-capacity $DESIRED_CAPACITY
        fi
        ;;
    *)
        echo "Usage: $0 {shutdown|startup|scale-agents [count]}"
        exit 1
        ;;
esac
SCRIPTEOF

chmod +x /usr/local/bin/jenkins-cost-optimizer.sh

# Create CloudWatch agent configuration for monitoring
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CWEOF
{
    "metrics": {
        "namespace": "Jenkins/CostOptimization",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 300
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
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/jenkins/jenkins.log",
                        "log_group_name": "/aws/ec2/jenkins",
                        "log_stream_name": "{instance_id}/jenkins.log"
                    }
                ]
            }
        }
    }
}
CWEOF

echo "Jenkins master installation and configuration completed!"
echo "Jenkins will be available at http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8080"
echo "Default admin credentials: admin / $JENKINS_ADMIN_PASSWORD"
