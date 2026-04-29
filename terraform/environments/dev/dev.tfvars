env                    = "dev"
aws_region             = "us-east-2"
ecr_region             = "us-east-1"
vpc_cidr               = "10.0.0.0/16"
availability_zones     = ["us-east-2a", "us-east-2b"]
cpu                    = 256
memory                 = 512
desired_count          = 1
github_repo            = "secant78/todo-pipeline"
github_branch          = "dev"
deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
single_nat_gateway     = true
rds_instance_class     = "db.t3.micro"
rds_allocated_storage  = 20

# aws_account_id, backend_image_tag, frontend_image_tag injected at runtime via -var flags
