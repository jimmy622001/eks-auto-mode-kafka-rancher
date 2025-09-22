import json
import boto3
import os
from datetime import datetime

def handler(event, context):
    """
    AWS Lambda function for Jenkins cost optimization
    Handles automatic shutdown/startup of Jenkins master and scaling of agents
    """
    
    print(f"Received event: {json.dumps(event, default=str)}")
    
    # Get environment variables
    jenkins_instance_id = os.environ.get('JENKINS_INSTANCE_ID')
    asg_name = os.environ.get('ASG_NAME')
    
    if not jenkins_instance_id:
        return {
            'statusCode': 400,
            'body': json.dumps('Missing JENKINS_INSTANCE_ID environment variable')
        }
    
    # Initialize AWS clients
    ec2_client = boto3.client('ec2')
    autoscaling_client = boto3.client('autoscaling')
    cloudwatch_client = boto3.client('cloudwatch')
    
    try:
        # Parse the action from the event
        action = event.get('action', 'unknown')
        print(f"Executing action: {action}")
        
        if action == 'shutdown':
            result = shutdown_jenkins_infrastructure(
                ec2_client, autoscaling_client, cloudwatch_client,
                jenkins_instance_id, asg_name
            )
        elif action == 'startup':
            result = startup_jenkins_infrastructure(
                ec2_client, autoscaling_client, cloudwatch_client,
                jenkins_instance_id, asg_name
            )
        elif action == 'scale_agents':
            desired_capacity = event.get('desired_capacity', 0)
            result = scale_jenkins_agents(
                autoscaling_client, cloudwatch_client,
                asg_name, desired_capacity
            )
        elif action == 'cost_report':
            result = generate_cost_report(
                ec2_client, autoscaling_client, cloudwatch_client,
                jenkins_instance_id, asg_name
            )
        else:
            return {
                'statusCode': 400,
                'body': json.dumps(f'Unknown action: {action}')
            }
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully executed {action}',
                'result': result,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error executing cost optimization: {str(e)}')
        }

def shutdown_jenkins_infrastructure(ec2_client, autoscaling_client, cloudwatch_client, 
                                  jenkins_instance_id, asg_name):
    """Shutdown Jenkins infrastructure to save costs"""
    
    result = {
        'jenkins_master': 'not_changed',
        'agents_scaled': 0,
        'cost_savings': 'estimated'
    }
    
    try:
        # Check Jenkins master instance state
        response = ec2_client.describe_instances(InstanceIds=[jenkins_instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        instance_state = instance['State']['Name']
        
        print(f"Jenkins master current state: {instance_state}")
        
        # Stop Jenkins master if it's running
        if instance_state == 'running':
            print("Stopping Jenkins master instance...")
            ec2_client.stop_instances(InstanceIds=[jenkins_instance_id])
            result['jenkins_master'] = 'stopped'
            
            # Send custom metric
            cloudwatch_client.put_metric_data(
                Namespace='Jenkins/CostOptimization',
                MetricData=[
                    {
                        'MetricName': 'MasterInstanceStopped',
                        'Value': 1,
                        'Unit': 'Count',
                        'Timestamp': datetime.utcnow()
                    }
                ]
            )
        else:
            print(f"Jenkins master already in state: {instance_state}")
        
        # Scale down Jenkins agents to 0
        if asg_name:
            agents_scaled = scale_jenkins_agents(
                autoscaling_client, cloudwatch_client, asg_name, 0
            )
            result['agents_scaled'] = agents_scaled.get('previous_capacity', 0)
        
        # Calculate estimated cost savings
        instance_type = instance.get('InstanceType', 't3.medium')
        estimated_hourly_savings = get_estimated_hourly_cost(instance_type)
        result['estimated_hourly_savings'] = f"${estimated_hourly_savings:.4f}"
        
        print(f"Shutdown completed: {result}")
        return result
        
    except Exception as e:
        print(f"Error during shutdown: {e}")
        raise

def startup_jenkins_infrastructure(ec2_client, autoscaling_client, cloudwatch_client,
                                 jenkins_instance_id, asg_name):
    """Startup Jenkins infrastructure for work hours"""
    
    result = {
        'jenkins_master': 'not_changed',
        'agents_ready': False,
        'startup_time': datetime.utcnow().isoformat()
    }
    
    try:
        # Check Jenkins master instance state
        response = ec2_client.describe_instances(InstanceIds=[jenkins_instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        instance_state = instance['State']['Name']
        
        print(f"Jenkins master current state: {instance_state}")
        
        # Start Jenkins master if it's stopped
        if instance_state == 'stopped':
            print("Starting Jenkins master instance...")
            ec2_client.start_instances(InstanceIds=[jenkins_instance_id])
            result['jenkins_master'] = 'started'
            
            # Send custom metric
            cloudwatch_client.put_metric_data(
                Namespace='Jenkins/CostOptimization',
                MetricData=[
                    {
                        'MetricName': 'MasterInstanceStarted',
                        'Value': 1,
                        'Unit': 'Count',
                        'Timestamp': datetime.utcnow()
                    }
                ]
            )
            
            # Wait for instance to be running (with timeout)
            print("Waiting for Jenkins master to be running...")
            waiter = ec2_client.get_waiter('instance_running')
            waiter.wait(
                InstanceIds=[jenkins_instance_id],
                WaiterConfig={'Delay': 15, 'MaxAttempts': 20}
            )
            print("Jenkins master is now running")
            
        elif instance_state == 'running':
            print("Jenkins master is already running")
            result['jenkins_master'] = 'already_running'
        
        # Prepare agents for potential builds (but don't start them yet)
        # They will be started on-demand by the build trigger Lambda
        if asg_name:
            # Ensure ASG is configured but keep desired capacity at 0
            # Agents will be scaled up when builds are triggered
            result['agents_ready'] = True
        
        print(f"Startup completed: {result}")
        return result
        
    except Exception as e:
        print(f"Error during startup: {e}")
        raise

def scale_jenkins_agents(autoscaling_client, cloudwatch_client, asg_name, desired_capacity):
    """Scale Jenkins agents up or down"""
    
    if not asg_name:
        return {'error': 'No ASG name provided'}
    
    try:
        # Get current ASG state
        response = autoscaling_client.describe_auto_scaling_groups(
            AutoScalingGroupNames=[asg_name]
        )
        
        if not response['AutoScalingGroups']:
            return {'error': f'ASG {asg_name} not found'}
        
        asg = response['AutoScalingGroups'][0]
        current_capacity = asg['DesiredCapacity']
        
        print(f"Current agent capacity: {current_capacity}, desired: {desired_capacity}")
        
        if current_capacity != desired_capacity:
            print(f"Scaling agents from {current_capacity} to {desired_capacity}")
            
            autoscaling_client.set_desired_capacity(
                AutoScalingGroupName=asg_name,
                DesiredCapacity=desired_capacity,
                HonorCooldown=False
            )
            
            # Send custom metric
            cloudwatch_client.put_metric_data(
                Namespace='Jenkins/CostOptimization',
                MetricData=[
                    {
                        'MetricName': 'AgentsScaled',
                        'Value': desired_capacity,
                        'Unit': 'Count',
                        'Timestamp': datetime.utcnow(),
                        'Dimensions': [
                            {
                                'Name': 'AutoScalingGroup',
                                'Value': asg_name
                            }
                        ]
                    }
                ]
            )
            
            return {
                'previous_capacity': current_capacity,
                'new_capacity': desired_capacity,
                'scaled': True
            }
        else:
            return {
                'current_capacity': current_capacity,
                'scaled': False,
                'message': 'Already at desired capacity'
            }
            
    except Exception as e:
        print(f"Error scaling agents: {e}")
        raise

def generate_cost_report(ec2_client, autoscaling_client, cloudwatch_client,
                        jenkins_instance_id, asg_name):
    """Generate a cost optimization report"""
    
    try:
        report = {
            'timestamp': datetime.utcnow().isoformat(),
            'jenkins_master': {},
            'jenkins_agents': {},
            'cost_optimization': {}
        }
        
        # Get Jenkins master info
        response = ec2_client.describe_instances(InstanceIds=[jenkins_instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        
        report['jenkins_master'] = {
            'instance_id': jenkins_instance_id,
            'instance_type': instance.get('InstanceType', 'unknown'),
            'state': instance['State']['Name'],
            'launch_time': instance.get('LaunchTime', '').isoformat() if instance.get('LaunchTime') else None,
            'estimated_hourly_cost': f"${get_estimated_hourly_cost(instance.get('InstanceType', 't3.medium')):.4f}"
        }
        
        # Get Jenkins agents info
        if asg_name:
            asg_response = autoscaling_client.describe_auto_scaling_groups(
                AutoScalingGroupNames=[asg_name]
            )
            
            if asg_response['AutoScalingGroups']:
                asg = asg_response['AutoScalingGroups'][0]
                
                # Get running instances
                running_instances = []
                if asg['Instances']:
                    instance_ids = [inst['InstanceId'] for inst in asg['Instances']]
                    instances_response = ec2_client.describe_instances(InstanceIds=instance_ids)
                    
                    for reservation in instances_response['Reservations']:
                        for inst in reservation['Instances']:
                            if inst['State']['Name'] == 'running':
                                running_instances.append({
                                    'instance_id': inst['InstanceId'],
                                    'instance_type': inst.get('InstanceType', 'unknown'),
                                    'launch_time': inst.get('LaunchTime', '').isoformat() if inst.get('LaunchTime') else None,
                                    'spot_instance': inst.get('InstanceLifecycle') == 'spot'
                                })
                
                report['jenkins_agents'] = {
                    'asg_name': asg_name,
                    'desired_capacity': asg['DesiredCapacity'],
                    'running_instances': len(running_instances),
                    'instances': running_instances,
                    'spot_instances_enabled': True
                }
        
        # Cost optimization metrics
        total_running_instances = 1 if report['jenkins_master']['state'] == 'running' else 0
        total_running_instances += len(report['jenkins_agents'].get('instances', []))
        
        # Get CloudWatch metrics for the last 24 hours
        try:
            metrics_response = cloudwatch_client.get_metric_statistics(
                Namespace='Jenkins/CostOptimization',
                MetricName='MasterInstanceStopped',
                StartTime=datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0),
                EndTime=datetime.utcnow(),
                Period=3600,
                Statistics=['Sum']
            )
            
            shutdowns_today = sum([point['Sum'] for point in metrics_response['Datapoints']])
            
        except Exception as e:
            print(f"Error getting CloudWatch metrics: {e}")
            shutdowns_today = 0
        
        report['cost_optimization'] = {
            'total_running_instances': total_running_instances,
            'shutdowns_today': shutdowns_today,
            'spot_instances_used': True,
            'auto_scaling_enabled': True,
            'estimated_daily_savings': f"${get_estimated_hourly_cost('t3.medium') * 16:.2f}",  # 16 hours off
            'recommendations': generate_cost_recommendations(report)
        }
        
        return report
        
    except Exception as e:
        print(f"Error generating cost report: {e}")
        raise

def get_estimated_hourly_cost(instance_type):
    """Get estimated hourly cost for an instance type (rough estimates)"""
    
    # Rough on-demand pricing estimates (actual prices vary by region)
    pricing = {
        't3.micro': 0.0104,
        't3.small': 0.0208,
        't3.medium': 0.0416,
        't3.large': 0.0832,
        't3.xlarge': 0.1664,
        't3.2xlarge': 0.3328,
        'm5.large': 0.096,
        'm5.xlarge': 0.192,
        'm5.2xlarge': 0.384,
        'c5.large': 0.085,
        'c5.xlarge': 0.17,
        'c5.2xlarge': 0.34
    }
    
    return pricing.get(instance_type, 0.05)  # Default fallback

def generate_cost_recommendations(report):
    """Generate cost optimization recommendations based on the report"""
    
    recommendations = []
    
    # Check if master is running during off-hours
    current_hour = datetime.utcnow().hour
    if current_hour < 8 or current_hour > 22:  # Outside 8 AM - 10 PM UTC
        if report['jenkins_master']['state'] == 'running':
            recommendations.append("Consider stopping Jenkins master during off-hours (currently running)")
    
    # Check agent utilization
    running_agents = len(report['jenkins_agents'].get('instances', []))
    if running_agents > 0:
        recommendations.append(f"Currently running {running_agents} agents - ensure they're being utilized")
    
    # Spot instance recommendations
    if not all(inst.get('spot_instance', False) for inst in report['jenkins_agents'].get('instances', [])):
        recommendations.append("Consider using spot instances for all agents to reduce costs")
    
    # Auto-scaling recommendations
    if report['jenkins_agents'].get('desired_capacity', 0) > 0:
        recommendations.append("Consider scaling down agents when not in use")
    
    if not recommendations:
        recommendations.append("Cost optimization is working well!")
    
    return recommendations

# Example usage for testing
if __name__ == "__main__":
    # Test event for shutdown
    test_event = {
        "action": "shutdown"
    }
    
    # Mock context
    class MockContext:
        def __init__(self):
            self.aws_request_id = "test-request-id"
    
    # Set environment variables for testing
    os.environ['JENKINS_INSTANCE_ID'] = 'i-1234567890abcdef0'
    os.environ['ASG_NAME'] = 'test-jenkins-agents-asg'
    
    result = handler(test_event, MockContext())
    print(json.dumps(result, indent=2))
