# ── Root Terragrunt config ────────────────────────────────────────────────────
# All child configs include this file via find_in_parent_folders().
# It generates the S3 backend and AWS provider so neither is duplicated
# across environment configs.

locals {
  # Derive the environment name from the directory containing the child config
  # (e.g.  terraform/environments/dev  →  "dev")
  env = basename(get_terragrunt_dir())
}

# Generate a backend.tf in the working directory so Terraform knows where
# to store state.  Each environment gets its own key — no workspaces needed.
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "todo-pipeline-tfstate"
    key            = "todo-pipeline/environments/${local.env}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "todo-pipeline-tflock"
    encrypt        = true
  }
}

# Generate a provider.tf so the provider block isn't repeated per environment.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.5"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }

    provider "aws" {
      region = var.aws_region
    }
  EOF
}
