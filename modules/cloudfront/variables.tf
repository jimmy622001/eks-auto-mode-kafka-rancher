variable "eks_endpoint" {
  description = "The endpoint of the EKS cluster"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the CDN resources"
  type        = map(string)
  default     = { ctse = "true" }
}