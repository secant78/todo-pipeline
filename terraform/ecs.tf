# ── Cluster ───────────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "todo-${local.env}"

  # Container Insights publishes per-task CPU/memory metrics to CloudWatch
  # automatically — no agent or sidecar needed with Fargate.
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

# ── Backend task definition ───────────────────────────────────────────────────
resource "aws_ecs_task_definition" "backend" {
  family                   = "todo-${local.env}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.config.cpu
  memory                   = local.config.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  # Mount the EFS access point at /data inside the container.
  # SQLite writes todo.db to /data/todo.db, which is persisted on EFS.
  volume {
    name = "sqlite-data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.db.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.db.id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
      essential = true

      portMappings = [{ containerPort = 5000, protocol = "tcp" }]

      mountPoints = [{
        sourceVolume  = "sqlite-data"
        containerPath = "/data"
        readOnly      = false
      }]

      environment = [
        { name = "APP_ENV", value = local.env },
        { name = "DB_PATH", value = "/data/todo.db" },
      ]

      # JWT_SECRET_KEY is pulled from Secrets Manager at task start by the ECS
      # agent — the value is never stored in the task definition or state file.
      secrets = [{
        name      = "JWT_SECRET_KEY"
        valueFrom = aws_secretsmanager_secret.jwt_secret.arn
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])

  tags = local.common_tags
}

# ── Frontend task definition ──────────────────────────────────────────────────
resource "aws_ecs_task_definition" "frontend" {
  family                   = "todo-${local.env}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  # Frontend is static nginx — minimal resources are fine
  cpu    = 256
  memory = 512
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:${var.frontend_image_tag}"
      essential = true

      portMappings = [{ containerPort = 80, protocol = "tcp" }]

      environment = [
        { name = "APP_ENV", value = local.env },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])

  tags = local.common_tags
}

# ── ECS Services ──────────────────────────────────────────────────────────────
resource "aws_ecs_service" "backend" {
  name            = "todo-${local.env}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = local.config.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 5000
  }

  # Rolling deployment: ECS starts new tasks before stopping old ones so there
  # is no downtime during updates.  The pipeline's rollback step reverts the
  # task definition if health checks fail.
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.http, aws_efs_mount_target.db[0]]
  tags       = local.common_tags
}

resource "aws_ecs_service" "frontend" {
  name            = "todo-${local.env}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = local.config.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.http]
  tags       = local.common_tags
}
