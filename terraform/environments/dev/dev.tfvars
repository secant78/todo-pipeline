env                    = "dev"
aws_region             = "us-east-1"
vpc_cidr               = "10.0.0.0/16"
availability_zones     = ["us-east-1a", "us-east-1b"]
cpu                    = 256
memory                 = 512
desired_count          = 1
github_repo            = "secant78/todo-pipeline"
github_branch          = "dev"
deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

# aws_account_id, backend_image_tag, frontend_image_tag injected at runtime via -var flags
