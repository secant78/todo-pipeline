include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../stack"
}

inputs = {
  env                = "prod"
  aws_region         = "us-east-1"
  vpc_cidr           = "10.2.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  cpu                = 1024
  memory             = 2048
  desired_count      = 2
  github_repo            = "secant78/todo-pipeline"
  github_branch          = "main"
  deployment_config_name = "CodeDeployDefault.ECSLinear10PercentEvery1Minute"
}
