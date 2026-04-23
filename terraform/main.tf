terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in S3 so all three workspace states are stored centrally.
  # The workspace name is automatically appended to the key, so each env gets
  # its own state file under todo-pipeline/<workspace>/terraform.tfstate.
  backend "s3" {
    bucket         = "todo-pipeline-tfstate"
    key            = "todo-pipeline/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "todo-pipeline-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  # terraform.workspace is "dev", "staging", or "prod" — set by the pipeline
  # with `terraform workspace select <env>` before plan/apply.
  env = terraform.workspace

  # Per-environment sizing.  dev is minimal; prod runs 2 tasks for redundancy.
  env_config = {
    dev = {
      cpu           = 256
      memory        = 512
      desired_count = 1
    }
    staging = {
      cpu           = 512
      memory        = 1024
      desired_count = 1
    }
    prod = {
      cpu           = 1024
      memory        = 2048
      desired_count = 2
    }
  }

  config = local.env_config[local.env]

  # Tag every resource so cost allocation and filtering are easy in the console
  common_tags = {
    Project     = "todo-pipeline"
    Environment = local.env
    ManagedBy   = "terraform"
  }
}
