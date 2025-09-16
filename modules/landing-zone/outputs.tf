output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organization"
  value       = aws_organizations_organization.main.arn
}

output "organizational_unit_id" {
  description = "ID of the main organizational unit"
  value       = aws_organizations_organizational_unit.main.id
}