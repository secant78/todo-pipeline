locals {
  backend_image        = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/todo-pipeline/backend:${var.backend_image_tag}"
  frontend_image       = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/todo-pipeline/frontend:${var.frontend_image_tag}"
  backend_log_group    = "/ecs/todo-${var.env}/backend"
  frontend_log_group   = "/ecs/todo-${var.env}/frontend"
}

resource "aws_ecs_cluster" "main" {
  name = "todo-${var.env}"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = var.common_tags
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "todo-${var.env}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  volume {
    name = "sqlite-data"
    efs_volume_configuration {
      file_system_id     = var.efs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_access_point_id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([{
    name      = "backend"
    image     = local.backend_image
    essential = true
    portMappings = [{ containerPort = 5000, protocol = "tcp" }]
    mountPoints = [{
      sourceVolume  = "sqlite-data"
      containerPath = "/data"
      readOnly      = false
    }]
    environment = [
      { name = "APP_ENV", value = var.env },
      { name = "DB_PATH", value = "/data/todo.db" },
    ]
    secrets = [{
      name      = "JWT_SECRET_KEY"
      valueFrom = var.jwt_secret_arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = local.backend_log_group
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])

  tags = var.common_tags
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "todo-${var.env}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = local.frontend_image
    essential = true
    portMappings = [{ containerPort = 80, protocol = "tcp" }]
    environment = [
      { name = "APP_ENV", value = var.env },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = local.frontend_log_group
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])

  tags = var.common_tags
}

resource "aws_ecs_service" "backend" {
  name            = "todo-${var.env}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.backend_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.backend_tg_arn
    container_name   = "backend"
    container_port   = 5000
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  tags = var.common_tags
}

resource "aws_ecs_service" "frontend" {
  name            = "todo-${var.env}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.frontend_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.frontend_tg_arn
    container_name   = "frontend"
    container_port   = 80
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  tags = var.common_tags
}
