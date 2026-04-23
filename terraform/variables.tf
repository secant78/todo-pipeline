variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID (used to construct ECR URLs)"
  type        = string
}

variable "backend_image_tag" {
  description = "Docker image tag for the backend container (set by the pipeline to the git SHA)"
  type        = string
}

variable "frontend_image_tag" {
  description = "Docker image tag for the frontend container (set by the pipeline to the git SHA)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
