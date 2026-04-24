include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../stack"
}

inputs = {
  env                = "staging"
  aws_region         = "us-east-1"
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  cpu                = 512
  memory             = 1024
  desired_count      = 1
  github_repo            = "secant78/todo-pipeline"
  github_branch          = "staging"
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"
}
