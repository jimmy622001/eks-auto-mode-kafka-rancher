output "jenkins_master_instance_id" {
  description = "Instance ID of the Jenkins master"
  value       = aws_instance.jenkins_master.id
}

output "jenkins_master_private_ip" {
  description = "Private IP address of the Jenkins master"
  value       = aws_instance.jenkins_master.private_ip
}

output "jenkins_url" {
  description = "Jenkins web interface URL"
  value       = "http://${aws_instance.jenkins_master.private_ip}:8080"
}

output "jenkins_alb_dns_name" {
  description = "DNS name of the Jenkins Application Load Balancer"
  value       = var.enable_jenkins_alb ? aws_lb.jenkins[0].dns_name : null
}

output "jenkins_alb_url" {
  description = "Jenkins ALB URL"
  value       = var.enable_jenkins_alb ? "http://${aws_lb.jenkins[0].dns_name}" : null
}

output "s3_artifacts_bucket" {
  description = "S3 bucket name for Jenkins artifacts"
  value       = aws_s3_bucket.jenkins_artifacts.bucket
}

output "s3_artifacts_bucket_arn" {
  description = "S3 bucket ARN for Jenkins artifacts"
  value       = aws_s3_bucket.jenkins_artifacts.arn
}

output "lambda_trigger_function_name" {
  description = "Name of the Lambda function that triggers Jenkins builds"
  value       = aws_lambda_function.jenkins_trigger.function_name
}

output "lambda_trigger_function_arn" {
  description = "ARN of the Lambda function that triggers Jenkins builds"
  value       = aws_lambda_function.jenkins_trigger.arn
}

output "jenkins_master_security_group_id" {
  description = "Security group ID for Jenkins master"
  value       = aws_security_group.jenkins_master.id
}

output "jenkins_agents_security_group_id" {
  description = "Security group ID for Jenkins agents"
  value       = aws_security_group.jenkins_agents.id
}

output "jenkins_agents_asg_name" {
  description = "Auto Scaling Group name for Jenkins agents"
  value       = aws_autoscaling_group.jenkins_agents.name
}

output "jenkins_agents_asg_arn" {
  description = "Auto Scaling Group ARN for Jenkins agents"
  value       = aws_autoscaling_group.jenkins_agents.arn
}

output "jenkins_master_role_arn" {
  description = "IAM role ARN for Jenkins master"
  value       = aws_iam_role.jenkins_master.arn
}

output "jenkins_agents_role_arn" {
  description = "IAM role ARN for Jenkins agents"
  value       = aws_iam_role.jenkins_agents.arn
}

output "jenkins_key_pair_name" {
  description = "Key pair name for Jenkins instances"
  value       = aws_key_pair.jenkins.key_name
}

output "ssm_parameter_admin_password" {
  description = "SSM parameter name for Jenkins admin password"
  value       = aws_ssm_parameter.jenkins_admin_password.name
  sensitive   = true
}

output "ssm_parameter_github_token" {
  description = "SSM parameter name for GitHub token"
  value       = aws_ssm_parameter.github_token.name
  sensitive   = true
}

# Cost optimization information
output "cost_optimization_info" {
  description = "Information about cost optimization features"
  value = {
    spot_instances_enabled = true
    auto_shutdown_enabled  = var.enable_auto_shutdown
    shutdown_schedule      = var.shutdown_schedule
    startup_schedule       = var.startup_schedule
    spot_max_price         = var.spot_max_price
    agent_idle_timeout     = var.agent_idle_timeout
    max_agents             = var.max_jenkins_agents
  }
}

# Trigger mechanisms
output "trigger_mechanisms" {
  description = "Available trigger mechanisms for Jenkins builds"
  value = {
    lambda_function = {
      name = aws_lambda_function.jenkins_trigger.function_name
      arn  = aws_lambda_function.jenkins_trigger.arn
    }
    s3_trigger = {
      bucket = aws_s3_bucket.jenkins_artifacts.bucket
      prefix = "triggers/"
      suffix = ".trigger"
    }
    eventbridge_rule = {
      name = aws_cloudwatch_event_rule.github_push.name
      arn  = aws_cloudwatch_event_rule.github_push.arn
    }
  }
}
