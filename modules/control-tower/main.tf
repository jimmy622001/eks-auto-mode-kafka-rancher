
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_organizations_organization" "control_tower" {
  feature_set = "ALL"

  aws_service_access_principals = [
    "controltower.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com"
  ]
}

resource "aws_organizations_account" "audit" {
  name  = "Audit Account"
  email = var.audit_email

  depends_on = [aws_organizations_organization.control_tower]
}

resource "aws_organizations_account" "log_archive" {
  name  = "Log Archive"
  email = var.log_archive_email

  depends_on = [aws_organizations_organization.control_tower]
}

# Create mandatory Control Tower SNS topics
resource "aws_sns_topic" "control_tower_notifications" {
  name = "aws-controltower-AllConfigNotifications"
}

resource "aws_sns_topic" "security_notifications" {
  name = "aws-controltower-SecurityNotifications"
}

# Enable AWS Config
resource "aws_config_configuration_recorder" "control_tower" {
  name     = "config-recorder"
  role_arn = aws_iam_role.config_recorder.arn

  recording_group {
    all_supported = true
  }
}

resource "aws_config_configuration_recorder_status" "control_tower" {
  name       = aws_config_configuration_recorder.control_tower.name
  is_enabled = true
  depends_on = [aws_config_configuration_recorder.control_tower]
}

resource "aws_iam_role" "config_recorder" {
  name = "aws-config-recorder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

# Attach required AWS Config policies to the IAM role
resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy_attachment" "config_policy_s3" {
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/AWSConfigServiceRolePolicy"
}