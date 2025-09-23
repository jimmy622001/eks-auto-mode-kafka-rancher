resource "aws_secretsmanager_secret" "security_tokens" {
  name        = "${var.cluster_name}-security-tokens"
  description = "Security tokens for ${var.cluster_name} cluster"

  tags = {
    Name        = "${var.cluster_name}-security-tokens"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "security_tokens" {
  secret_id = aws_secretsmanager_secret.security_tokens.id
  secret_string = jsonencode({
    github_token     = var.github_token
    sonarqube_token  = var.sonarqube_token
    snyk_token       = var.snyk_token
    trivy_token      = var.trivy_token
  })
}

# IAM policy to allow EKS nodes to read the secret
resource "aws_iam_policy" "eks_secrets_access" {
  name        = "${var.cluster_name}-secrets-access"
  description = "Allows EKS nodes to read security tokens from Secrets Manager"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.security_tokens.arn
      }
    ]
  })
}
