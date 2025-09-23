output "security_tokens_secret_arn" {
  description = "ARN of the security tokens secret"
  value       = aws_secretsmanager_secret.security_tokens.arn
}

output "security_tokens_secret_name" {
  description = "Name of the security tokens secret"
  value       = aws_secretsmanager_secret.security_tokens.name
}

output "secrets_access_policy_arn" {
  description = "ARN of the IAM policy for accessing the secrets"
  value       = aws_iam_policy.eks_secrets_access.arn
}
