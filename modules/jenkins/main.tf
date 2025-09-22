locals {
  jenkins_name = "${var.cluster_name}-jenkins"
  common_tags = merge(var.tags, {
    Component = "Jenkins"
    Service   = "CI/CD"
  })
}

# S3 bucket for Jenkins artifacts and build triggers
resource "aws_s3_bucket" "jenkins_artifacts" {
  bucket = "${local.jenkins_name}-artifacts-${random_string.bucket_suffix.result}"

  tags = local.common_tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "jenkins_artifacts" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Security Group for Jenkins Master
resource "aws_security_group" "jenkins_master" {
  name        = "${local.jenkins_name}-master"
  description = "Security group for Jenkins master"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Jenkins web interface"
  }

  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Jenkins agent communication"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.jenkins_name}-master-sg"
  })
}

# Security Group for Jenkins Agents (Spot Instances)
resource "aws_security_group" "jenkins_agents" {
  name        = "${local.jenkins_name}-agents"
  description = "Security group for Jenkins agents"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_master.id]
    description     = "SSH from Jenkins master"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.jenkins_name}-agents-sg"
  })
}

# IAM Role for Jenkins Master
resource "aws_iam_role" "jenkins_master" {
  name = "${local.jenkins_name}-master-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Jenkins Master
resource "aws_iam_policy" "jenkins_master" {
  name        = "${local.jenkins_name}-master-policy"
  description = "Policy for Jenkins master to manage EC2 Spot instances and S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeSpotInstanceRequests",
          "ec2:DescribeSpotPriceHistory",
          "ec2:RequestSpotInstances",
          "ec2:CancelSpotInstanceRequests",
          "ec2:CreateTags",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.jenkins_artifacts.arn,
          "${aws_s3_bucket.jenkins_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/jenkins/*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "jenkins_master" {
  role       = aws_iam_role.jenkins_master.name
  policy_arn = aws_iam_policy.jenkins_master.arn
}

resource "aws_iam_instance_profile" "jenkins_master" {
  name = "${local.jenkins_name}-master-profile"
  role = aws_iam_role.jenkins_master.name

  tags = local.common_tags
}

# IAM Role for Jenkins Agents
resource "aws_iam_role" "jenkins_agents" {
  name = "${local.jenkins_name}-agents-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Jenkins Agents
resource "aws_iam_policy" "jenkins_agents" {
  name        = "${local.jenkins_name}-agents-policy"
  description = "Policy for Jenkins agents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.jenkins_artifacts.arn,
          "${aws_s3_bucket.jenkins_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "jenkins_agents" {
  role       = aws_iam_role.jenkins_agents.name
  policy_arn = aws_iam_policy.jenkins_agents.arn
}

resource "aws_iam_instance_profile" "jenkins_agents" {
  name = "${local.jenkins_name}-agents-profile"
  role = aws_iam_role.jenkins_agents.name

  tags = local.common_tags
}

# Key Pair for Jenkins instances
resource "aws_key_pair" "jenkins" {
  key_name   = "${local.jenkins_name}-keypair"
  public_key = var.jenkins_public_key

  tags = local.common_tags
}

# Launch Template for Jenkins Master
resource "aws_launch_template" "jenkins_master" {
  name_prefix   = "${local.jenkins_name}-master-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.jenkins_master_instance_type
  key_name      = aws_key_pair.jenkins.key_name

  vpc_security_group_ids = [aws_security_group.jenkins_master.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.jenkins_master.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data/jenkins_master.sh", {
    jenkins_admin_password = var.jenkins_admin_password
    s3_bucket              = aws_s3_bucket.jenkins_artifacts.bucket
    aws_region             = var.aws_region
    github_token           = var.github_token
    github_webhook_secret  = var.github_webhook_secret
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.jenkins_name}-master"
      Type = "jenkins-master"
    })
  }

  tags = local.common_tags
}

# Launch Template for Jenkins Agents (Spot Instances)
resource "aws_launch_template" "jenkins_agents" {
  name_prefix   = "${local.jenkins_name}-agents-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.jenkins_agent_instance_type
  key_name      = aws_key_pair.jenkins.key_name

  vpc_security_group_ids = [aws_security_group.jenkins_agents.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.jenkins_agents.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data/jenkins_agent.sh", {
    jenkins_master_url = "http://${aws_instance.jenkins_master.private_ip}:8080"
    s3_bucket          = aws_s3_bucket.jenkins_artifacts.bucket
    aws_region         = var.aws_region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.jenkins_name}-agent"
      Type = "jenkins-agent"
    })
  }

  tags = local.common_tags
}

# Jenkins Master Instance
resource "aws_instance" "jenkins_master" {
  launch_template {
    id      = aws_launch_template.jenkins_master.id
    version = "$Latest"
  }

  subnet_id                   = var.private_subnets[0]
  associate_public_ip_address = false

  root_block_device {
    volume_type = "gp3"
    volume_size = var.jenkins_master_volume_size
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.jenkins_name}-master"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for Jenkins Agents (Spot Instances)
resource "aws_autoscaling_group" "jenkins_agents" {
  name                      = "${local.jenkins_name}-agents-asg"
  vpc_zone_identifier       = var.private_subnets
  target_group_arns         = []
  health_check_type         = "EC2"
  health_check_grace_period = 300

  min_size         = 0
  max_size         = var.max_jenkins_agents
  desired_capacity = 0

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.jenkins_agents.id
        version            = "$Latest"
      }

      override {
        instance_type     = var.jenkins_agent_instance_type
        weighted_capacity = "1"
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "diversified"
      spot_instance_pools                      = 3
      spot_max_price                           = var.spot_max_price
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.jenkins_name}-agent"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Lambda function to trigger Jenkins builds
resource "aws_lambda_function" "jenkins_trigger" {
  filename         = data.archive_file.jenkins_trigger.output_path
  function_name    = "${local.jenkins_name}-trigger"
  role             = aws_iam_role.lambda_jenkins_trigger.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.jenkins_trigger.output_base64sha256
  runtime          = "python3.9"
  timeout          = 60

  environment {
    variables = {
      JENKINS_URL      = "http://${aws_instance.jenkins_master.private_ip}:8080"
      JENKINS_USER     = "admin"
      JENKINS_PASSWORD = var.jenkins_admin_password
      S3_BUCKET        = aws_s3_bucket.jenkins_artifacts.bucket
    }
  }

  tags = local.common_tags
}

# Lambda function code
data "archive_file" "jenkins_trigger" {
  type        = "zip"
  output_path = "${path.module}/jenkins_trigger.zip"
  source {
    content = templatefile("${path.module}/lambda/jenkins_trigger.py", {
      jenkins_url = "http://${aws_instance.jenkins_master.private_ip}:8080"
    })
    filename = "index.py"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_jenkins_trigger" {
  name = "${local.jenkins_name}-lambda-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_jenkins_trigger" {
  name        = "${local.jenkins_name}-lambda-trigger-policy"
  description = "Policy for Lambda to trigger Jenkins builds"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = aws_autoscaling_group.jenkins_agents.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.jenkins_artifacts.arn,
          "${aws_s3_bucket.jenkins_artifacts.arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_jenkins_trigger" {
  role       = aws_iam_role.lambda_jenkins_trigger.name
  policy_arn = aws_iam_policy.lambda_jenkins_trigger.arn
}

# S3 Event Notification for triggering builds
resource "aws_s3_bucket_notification" "jenkins_trigger" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.jenkins_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "triggers/"
    filter_suffix       = ".trigger"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jenkins_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.jenkins_artifacts.arn
}

# EventBridge rule for GitHub webhooks (alternative trigger)
resource "aws_cloudwatch_event_rule" "github_push" {
  name        = "${local.jenkins_name}-github-push"
  description = "Trigger Jenkins build on GitHub push"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    detail = {
      event = ["referenceCreated", "referenceUpdated"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "jenkins_trigger" {
  rule      = aws_cloudwatch_event_rule.github_push.name
  target_id = "JenkinsTriggerTarget"
  arn       = aws_lambda_function.jenkins_trigger.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jenkins_trigger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.github_push.arn
}

# Application Load Balancer for Jenkins (optional)
resource "aws_lb" "jenkins" {
  count              = var.enable_jenkins_alb ? 1 : 0
  name               = "${local.jenkins_name}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jenkins_alb[0].id]
  subnets            = var.private_subnets

  enable_deletion_protection = false

  tags = local.common_tags
}

resource "aws_security_group" "jenkins_alb" {
  count       = var.enable_jenkins_alb ? 1 : 0
  name        = "${local.jenkins_name}-alb-sg"
  description = "Security group for Jenkins ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.jenkins_name}-alb-sg"
  })
}

resource "aws_lb_target_group" "jenkins" {
  count    = var.enable_jenkins_alb ? 1 : 0
  name     = "${local.jenkins_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,403"
    path                = "/login"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

resource "aws_lb_target_group_attachment" "jenkins" {
  count            = var.enable_jenkins_alb ? 1 : 0
  target_group_arn = aws_lb_target_group.jenkins[0].arn
  target_id        = aws_instance.jenkins_master.id
  port             = 8080
}

resource "aws_lb_listener" "jenkins" {
  count             = var.enable_jenkins_alb ? 1 : 0
  load_balancer_arn = aws_lb.jenkins[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins[0].arn
  }

  tags = local.common_tags
}

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSM Parameters for Jenkins configuration
resource "aws_ssm_parameter" "jenkins_admin_password" {
  name  = "/jenkins/${local.jenkins_name}/admin-password"
  type  = "SecureString"
  value = var.jenkins_admin_password

  tags = local.common_tags
}

resource "aws_ssm_parameter" "github_token" {
  name  = "/jenkins/${local.jenkins_name}/github-token"
  type  = "SecureString"
  value = var.github_token

  tags = local.common_tags
}

# Cost Optimization: Auto-shutdown and startup schedules
resource "aws_cloudwatch_event_rule" "jenkins_shutdown" {
  count               = var.enable_auto_shutdown ? 1 : 0
  name                = "${local.jenkins_name}-auto-shutdown"
  description         = "Automatically shutdown Jenkins master during off-hours"
  schedule_expression = "cron(${var.shutdown_schedule})"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "jenkins_startup" {
  count               = var.enable_auto_shutdown ? 1 : 0
  name                = "${local.jenkins_name}-auto-startup"
  description         = "Automatically startup Jenkins master during work hours"
  schedule_expression = "cron(${var.startup_schedule})"

  tags = local.common_tags
}

# Lambda function for cost optimization (shutdown/startup)
resource "aws_lambda_function" "jenkins_cost_optimizer" {
  count            = var.enable_auto_shutdown ? 1 : 0
  filename         = data.archive_file.jenkins_cost_optimizer[0].output_path
  function_name    = "${local.jenkins_name}-cost-optimizer"
  role             = aws_iam_role.lambda_cost_optimizer[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.jenkins_cost_optimizer[0].output_base64sha256
  runtime          = "python3.9"
  timeout          = 300

  environment {
    variables = {
      JENKINS_INSTANCE_ID = aws_instance.jenkins_master.id
      ASG_NAME            = aws_autoscaling_group.jenkins_agents.name
    }
  }

  tags = local.common_tags
}

data "archive_file" "jenkins_cost_optimizer" {
  count       = var.enable_auto_shutdown ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/jenkins_cost_optimizer.zip"
  source {
    content = templatefile("${path.module}/lambda/cost_optimizer.py", {
      jenkins_instance_id = aws_instance.jenkins_master.id
      asg_name            = aws_autoscaling_group.jenkins_agents.name
    })
    filename = "index.py"
  }
}

resource "aws_iam_role" "lambda_cost_optimizer" {
  count = var.enable_auto_shutdown ? 1 : 0
  name  = "${local.jenkins_name}-lambda-cost-optimizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "lambda_cost_optimizer" {
  count       = var.enable_auto_shutdown ? 1 : 0
  name        = "${local.jenkins_name}-lambda-cost-optimizer-policy"
  description = "Policy for Lambda cost optimizer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = aws_autoscaling_group.jenkins_agents.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_cost_optimizer" {
  count      = var.enable_auto_shutdown ? 1 : 0
  role       = aws_iam_role.lambda_cost_optimizer[0].name
  policy_arn = aws_iam_policy.lambda_cost_optimizer[0].arn
}

# EventBridge targets for cost optimization
resource "aws_cloudwatch_event_target" "jenkins_shutdown" {
  count     = var.enable_auto_shutdown ? 1 : 0
  rule      = aws_cloudwatch_event_rule.jenkins_shutdown[0].name
  target_id = "JenkinsShutdownTarget"
  arn       = aws_lambda_function.jenkins_cost_optimizer[0].arn

  input = jsonencode({
    action = "shutdown"
  })
}

resource "aws_cloudwatch_event_target" "jenkins_startup" {
  count     = var.enable_auto_shutdown ? 1 : 0
  rule      = aws_cloudwatch_event_rule.jenkins_startup[0].name
  target_id = "JenkinsStartupTarget"
  arn       = aws_lambda_function.jenkins_cost_optimizer[0].arn

  input = jsonencode({
    action = "startup"
  })
}

resource "aws_lambda_permission" "eventbridge_shutdown" {
  count         = var.enable_auto_shutdown ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeShutdown"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jenkins_cost_optimizer[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.jenkins_shutdown[0].arn
}

resource "aws_lambda_permission" "eventbridge_startup" {
  count         = var.enable_auto_shutdown ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeStartup"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jenkins_cost_optimizer[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.jenkins_startup[0].arn
}
