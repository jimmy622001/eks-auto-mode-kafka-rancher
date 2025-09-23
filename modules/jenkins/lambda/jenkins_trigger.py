import json
import os
import urllib3
import base64
import boto3
from datetime import datetime

# Disable SSL warnings for internal Jenkins
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def handler(event, context):
    """
    AWS Lambda function to trigger Jenkins builds
    Supports multiple trigger sources: S3, EventBridge, API Gateway, etc.
    """
    
    print(f"Received event: {json.dumps(event, default=str)}")
    
    # Get environment variables
    jenkins_url = os.environ.get("JENKINS_URL")
    jenkins_user = os.environ.get("JENKINS_USER", "admin")
    jenkins_password = os.environ.get("JENKINS_PASSWORD")
    s3_bucket = os.environ.get("S3_BUCKET")
    
    if not all([jenkins_url, jenkins_password]):
        return {
            "statusCode": 400,
            "body": json.dumps("Missing required environment variables")
        }
    
    # Initialize AWS clients
    ec2_client = boto3.client("ec2")
    autoscaling_client = boto3.client("autoscaling")
    s3_client = boto3.client("s3")
    
    try:
        # Determine trigger source and extract build parameters
        trigger_source, build_params = parse_event(event)
        print(f"Trigger source: {trigger_source}")
        print(f"Build parameters: {build_params}")
        
        # Ensure Jenkins master is running
        jenkins_instance_id = ensure_jenkins_master_running(ec2_client)
        if not jenkins_instance_id:
            return {
                "statusCode": 500,
                "body": json.dumps("Failed to start Jenkins master")
            }
        
        # Scale up Jenkins agents if needed
        scale_jenkins_agents(autoscaling_client, build_params.get("agent_count", 1))
        
        # Wait for Jenkins to be ready
        if not wait_for_jenkins_ready(jenkins_url, jenkins_user, jenkins_password):
            return {
                "statusCode": 500,
                "body": json.dumps("Jenkins master is not ready")
            }
        
        # Trigger Jenkins build
        build_result = trigger_jenkins_build(
            jenkins_url, jenkins_user, jenkins_password, build_params
        )
        
        # Log build trigger to S3
        log_build_trigger(s3_client, s3_bucket, trigger_source, build_params, build_result)
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Jenkins build triggered successfully",
                "trigger_source": trigger_source,
                "build_number": build_result.get("build_number"),
                "job_name": build_params.get("job_name", "github-pipeline"),
                "jenkins_instance_id": jenkins_instance_id
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error triggering Jenkins build: {str(e)}")
        }

def parse_event(event):
    """Parse the incoming event to determine trigger source and build parameters"""
    
    # S3 Event (file upload trigger)
    if "Records" in event and event["Records"][0].get("eventSource") == "aws:s3":
        s3_record = event["Records"][0]["s3"]
        bucket = s3_record["bucket"]["name"]
        key = s3_record["object"]["key"]
        
        # Extract build parameters from S3 object key or metadata
        build_params = {
            "job_name": "github-pipeline",
            "trigger_type": "s3_upload",
            "source_bucket": bucket,
            "source_key": key,
            "agent_count": 1
        }
        
        # If it's a trigger file, parse additional parameters
        if key.startswith("triggers/") and key.endswith(".trigger"):
            try:
                s3_client = boto3.client("s3")
                response = s3_client.get_object(Bucket=bucket, Key=key)
                trigger_data = json.loads(response["Body"].read().decode("utf-8"))
                build_params.update(trigger_data)
            except Exception as e:
                print(f"Error parsing trigger file: {e}")
        
        return "s3_event", build_params
    
    # EventBridge Event (GitHub webhook or scheduled)
    elif "source" in event:
        if event["source"] == "aws.codecommit":
            build_params = {
                "job_name": "github-pipeline",
                "trigger_type": "codecommit_push",
                "repository": event["detail"].get("repositoryName", ""),
                "branch": event["detail"].get("referenceName", "main"),
                "agent_count": 1
            }
        else:
            build_params = {
                "job_name": "github-pipeline",
                "trigger_type": "eventbridge",
                "agent_count": 1
            }
        
        return "eventbridge", build_params
    
    # API Gateway Event (direct API call)
    elif "httpMethod" in event:
        body = {}
        if event.get("body"):
            try:
                body = json.loads(event["body"])
            except:
                pass
        
        build_params = {
            "job_name": body.get("job_name", "github-pipeline"),
            "trigger_type": "api_gateway",
            "branch": body.get("branch", "main"),
            "repository": body.get("repository", ""),
            "agent_count": body.get("agent_count", 1),
            "build_parameters": body.get("build_parameters", {})
        }
        
        return "api_gateway", build_params
    
    # GitHub Webhook (if configured to call Lambda directly)
    elif "repository" in event and "pusher" in event:
        build_params = {
            "job_name": "github-pipeline",
            "trigger_type": "github_webhook",
            "repository": event["repository"]["name"],
            "branch": event["ref"].replace("refs/heads/", ""),
            "commit_sha": event["head_commit"]["id"],
            "pusher": event["pusher"]["name"],
            "agent_count": 1
        }
        
        return "github_webhook", build_params
    
    # Default/Manual trigger
    else:
        build_params = {
            "job_name": event.get("job_name", "github-pipeline"),
            "trigger_type": "manual",
            "agent_count": event.get("agent_count", 1),
            "build_parameters": event.get("build_parameters", {})
        }
        
        return "manual", build_params

def ensure_jenkins_master_running(ec2_client):
    """Ensure Jenkins master instance is running"""
    
    try:
        # Find Jenkins master instance
        response = ec2_client.describe_instances(
            Filters=[
                {"Name": "tag:Type", "Values": ["jenkins-master"]},
                {"Name": "instance-state-name", "Values": ["running", "stopped"]}
            ]
        )
        
        if not response["Reservations"]:
            print("No Jenkins master instance found")
            return None
        
        instance = response["Reservations"][0]["Instances"][0]
        instance_id = instance["InstanceId"]
        instance_state = instance["State"]["Name"]
        
        if instance_state == "stopped":
            print(f"Starting Jenkins master instance: {instance_id}")
            ec2_client.start_instances(InstanceIds=[instance_id])
            
            # Wait for instance to be running
            waiter = ec2_client.get_waiter("instance_running")
            waiter.wait(InstanceIds=[instance_id], WaiterConfig={"Delay": 15, "MaxAttempts": 20})
            
        print(f"Jenkins master instance {instance_id} is running")
        return instance_id
        
    except Exception as e:
        print(f"Error managing Jenkins master instance: {e}")
        return None

def scale_jenkins_agents(autoscaling_client, desired_count):
    """Scale Jenkins agents based on build requirements"""
    
    try:
        # Find Jenkins agents Auto Scaling Group
        response = autoscaling_client.describe_auto_scaling_groups()
        
        jenkins_asg = None
        for asg in response["AutoScalingGroups"]:
            for tag in asg.get("Tags", []):
                if tag["Key"] == "Name" and "jenkins-agent" in tag["Value"]:
                    jenkins_asg = asg
                    break
            if jenkins_asg:
                break
        
        if not jenkins_asg:
            print("Jenkins agents Auto Scaling Group not found")
            return
        
        asg_name = jenkins_asg["AutoScalingGroupName"]
        current_capacity = jenkins_asg["DesiredCapacity"]
        
        # Scale up if needed (but don't scale down automatically)
        if desired_count > current_capacity:
            print(f"Scaling Jenkins agents from {current_capacity} to {desired_count}")
            autoscaling_client.set_desired_capacity(
                AutoScalingGroupName=asg_name,
                DesiredCapacity=desired_count,
                HonorCooldown=False
            )
        else:
            print(f"Jenkins agents already at desired capacity: {current_capacity}")
            
    except Exception as e:
        print(f"Error scaling Jenkins agents: {e}")

def wait_for_jenkins_ready(jenkins_url, username, password, max_attempts=30):
    """Wait for Jenkins to be ready to accept requests"""
    
    http = urllib3.PoolManager()
    auth_header = base64.b64encode(f"{username}:{password}".encode()).decode()
    headers = {"Authorization": f"Basic {auth_header}"}
    
    for attempt in range(max_attempts):
        try:
            response = http.request("GET", f"{jenkins_url}/api/json", headers=headers, timeout=10)
            if response.status == 200:
                print("Jenkins is ready")
                return True
        except Exception as e:
            print(f"Attempt {attempt + 1}: Jenkins not ready - {e}")
        
        if attempt < max_attempts - 1:
            import time
            time.sleep(10)
    
    print("Jenkins failed to become ready")
    return False

def trigger_jenkins_build(jenkins_url, username, password, build_params):
    """Trigger a Jenkins build with the specified parameters"""
    
    http = urllib3.PoolManager()
    auth_header = base64.b64encode(f"{username}:{password}".encode()).decode()
    
    # Get CSRF crumb
    crumb_response = http.request(
        "GET",
        f"{jenkins_url}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)",
        headers={"Authorization": f"Basic {auth_header}"}
    )
    
    headers = {"Authorization": f"Basic {auth_header}"}
    if crumb_response.status == 200:
        crumb = crumb_response.data.decode()
        crumb_field, crumb_value = crumb.split(":")
        headers[crumb_field] = crumb_value
    
    job_name = build_params.get("job_name", "github-pipeline")
    
    # Prepare build parameters
    jenkins_params = {
        "TRIGGER_TYPE": build_params.get("trigger_type", "lambda"),
        "BRANCH": build_params.get("branch", "main"),
        "REPOSITORY": build_params.get("repository", ""),
        "COMMIT_SHA": build_params.get("commit_sha", ""),
        "TRIGGER_TIMESTAMP": datetime.utcnow().isoformat()
    }
    
    # Add custom build parameters
    if "build_parameters" in build_params:
        jenkins_params.update(build_params["build_parameters"])
    
    # Trigger build with parameters
    if jenkins_params:
        # Build with parameters
        params_data = "&".join([f"{k}={v}" for k, v in jenkins_params.items()])
        build_url = f"{jenkins_url}/job/{job_name}/buildWithParameters"
        
        response = http.request(
            "POST",
            build_url,
            body=params_data,
            headers={**headers, "Content-Type": "application/x-www-form-urlencoded"}
        )
    else:
        # Simple build trigger
        build_url = f"{jenkins_url}/job/{job_name}/build"
        response = http.request("POST", build_url, headers=headers)
    
    if response.status in [200, 201]:
        # Get queue item location from response headers
        queue_location = response.headers.get("Location", "")
        print(f"Build triggered successfully. Queue location: {queue_location}")
        
        return {
            "success": True,
            "queue_location": queue_location,
            "build_url": build_url,
            "parameters": jenkins_params
        }
    else:
        raise Exception(f"Failed to trigger build. Status: {response.status}, Response: {response.data.decode()}")

def log_build_trigger(s3_client, bucket, trigger_source, build_params, build_result):
    """Log build trigger information to S3 for cost tracking and auditing"""
    
    if not bucket:
        return
    
    try:
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "trigger_source": trigger_source,
            "build_params": build_params,
            "build_result": build_result,
            "lambda_request_id": os.environ.get("AWS_LAMBDA_REQUEST_ID", ""),
            "cost_optimization": {
                "spot_instances_used": True,
                "auto_scaling_enabled": True,
                "estimated_cost_per_build": 0.05  # Rough estimate
            }
        }
        
        log_key = f"build-triggers/{datetime.utcnow().strftime('%Y/%m/%d')}/trigger-{datetime.utcnow().strftime('%H%M%S')}-{os.environ.get('AWS_LAMBDA_REQUEST_ID', 'unknown')}.json"
        
        s3_client.put_object(
            Bucket=bucket,
            Key=log_key,
            Body=json.dumps(log_data, indent=2),
            ContentType="application/json"
        )
        
        print(f"Build trigger logged to S3: s3://{bucket}/{log_key}")
        
    except Exception as e:
        print(f"Error logging build trigger: {e}")

# Example usage for testing
if __name__ == "__main__":
    # Test event for S3 trigger
    test_event = {
        "Records": [
            {
                "eventSource": "aws:s3",
                "s3": {
                    "bucket": {"name": "test-bucket"},
                    "object": {"key": "triggers/build.trigger"}
                }
            }
        ]
    }
    
    # Mock context
    class MockContext:
        def __init__(self):
            self.aws_request_id = "test-request-id"
    
    result = handler(test_event, MockContext())
    print(json.dumps(result, indent=2))
