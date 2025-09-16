terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Create AWS Organization
resource "aws_organizations_organization" "main" {
  feature_set = "ALL"

  enabled_policy_types = ["SERVICE_CONTROL_POLICY", "TAG_POLICY"]

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com",
    "ram.amazonaws.com"
  ]
}

# Create Organizational Units
resource "aws_organizations_organizational_unit" "main" {
  name      = var.organization_name
  parent_id = aws_organizations_organization.main.roots[0].id
}

# Create sub-OUs
resource "aws_organizations_organizational_unit" "sub_ous" {
  for_each  = toset(var.organizational_units)
  name      = each.key
  parent_id = aws_organizations_organizational_unit.main.id
}