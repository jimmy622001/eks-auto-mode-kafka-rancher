# backend.hcl - Terraform backend configuration

# S3 bucket for storing the Terraform state
bucket         = var.s3_bucket_name
key            = "${var.cluster_name}/terraform.tfstate"
region         = var.aws_region

# Enable state locking with DynamoDB
dynamodb_table = "terraform-locks-${var.environment}"
encrypt        = true

# This file is included in .gitignore to prevent committing sensitive information
