terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket         = "todo-pipeline-tfstate"
    key            = "stack/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "todo-pipeline-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
