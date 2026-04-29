include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../stack"
}

inputs = {
  env                = "prod"
  aws_region         = "us-east-1"
  ecr_region         = "us-east-1"   # ECR and prod region are both us-east-1
  vpc_cidr           = "10.2.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  cpu                = 1024
  memory             = 2048
  desired_count      = 2
  single_nat_gateway     = false
  rds_instance_class     = "db.t3.small"
  rds_allocated_storage  = 30
  github_repo            = "secant78/todo-pipeline"
  github_branch          = "main"
  deployment_config_name = "CodeDeployDefault.ECSLinear10PercentEvery1Minute"
  use_codedeploy         = true

  # aws_account_id, backend_image_tag, frontend_image_tag injected at runtime via -var flags
}
