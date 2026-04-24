locals {
  common_tags = {
    Project     = "todo-pipeline"
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

module "iam" {
  source         = "../modules/iam"
  env            = var.env
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id
  github_repo    = var.github_repo
  github_branch  = var.github_branch
  common_tags    = local.common_tags
}

module "networking" {
  source             = "../modules/networking"
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  common_tags        = local.common_tags
}

module "secrets" {
  source            = "../modules/secrets"
  env               = var.env
  aws_region        = var.aws_region
  aws_account_id    = var.aws_account_id
  rotator_role_id   = module.iam.rotator_role_id
  execution_role_id = module.iam.execution_role_id
  rotator_zip_path  = "${path.module}/rotator.zip"
  common_tags       = local.common_tags
}

module "ecs" {
  source              = "../modules/ecs"
  env                 = var.env
  aws_region          = var.aws_region
  aws_account_id      = var.aws_account_id
  cpu                 = var.cpu
  memory              = var.memory
  desired_count       = var.desired_count
  backend_image_tag   = var.backend_image_tag
  frontend_image_tag  = var.frontend_image_tag
  execution_role_arn  = module.iam.execution_role_arn
  task_role_arn       = module.iam.task_role_arn
  subnet_ids          = module.networking.private_subnet_ids
  backend_sg_id       = module.networking.backend_sg_id
  frontend_sg_id      = module.networking.frontend_sg_id
  backend_tg_arn      = module.networking.backend_tg_arn
  frontend_tg_arn     = module.networking.frontend_tg_arn
  jwt_secret_arn      = module.secrets.jwt_secret_arn
  common_tags         = local.common_tags

  depends_on = [module.secrets]
}

module "monitoring" {
  source                = "../modules/monitoring"
  env                   = var.env
  aws_region            = var.aws_region
  memory                = var.memory
  cluster_name          = module.ecs.cluster_name
  backend_service_name  = module.ecs.backend_service_name
  alb_arn_suffix        = module.networking.alb_arn_suffix
  backend_tg_arn_suffix = module.networking.backend_tg_arn_suffix
  common_tags           = local.common_tags
}

module "codedeploy" {
  source                 = "../modules/codedeploy"
  env                    = var.env
  cluster_name           = module.ecs.cluster_name
  backend_service_name   = module.ecs.backend_service_name
  frontend_service_name  = module.ecs.frontend_service_name
  backend_blue_tg_name   = module.networking.backend_blue_tg_name
  backend_green_tg_name  = module.networking.backend_green_tg_name
  frontend_blue_tg_name  = module.networking.frontend_blue_tg_name
  frontend_green_tg_name = module.networking.frontend_green_tg_name
  prod_listener_arn      = module.networking.alb_listener_arn
  test_listener_arn      = module.networking.test_listener_arn
  rollback_alarm_names   = module.monitoring.rollback_alarm_names
  deployment_config_name = var.deployment_config_name
  common_tags            = local.common_tags

  depends_on = [module.ecs, module.monitoring]
}
