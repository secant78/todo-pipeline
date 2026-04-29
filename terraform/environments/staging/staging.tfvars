env                    = "staging"
aws_region             = "us-east-2"
vpc_cidr               = "10.1.0.0/16"
availability_zones     = ["us-east-2a", "us-east-2b"]
cpu                    = 512
memory                 = 1024
desired_count          = 2
github_repo            = "secant78/todo-pipeline"
github_branch          = "staging"
deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
single_nat_gateway     = false
rds_instance_class     = "db.t3.small"
rds_allocated_storage  = 20

# aws_account_id, backend_image_tag, frontend_image_tag injected at runtime via -var flags
