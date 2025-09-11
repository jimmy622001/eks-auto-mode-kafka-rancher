variable "aws_region" {
  type        = string
  description = "AWS region"

}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "rancher_admin_password" {
  type      = string
  sensitive = true
}