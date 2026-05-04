resource "random_password" "db" {
  length  = 32
  special = false # avoid chars that break connection strings
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "todo-${var.env}/db-password"
  recovery_window_in_days = 0
  tags                    = var.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

# Grant the ECS execution role permission to read the DB password at task start
resource "aws_iam_role_policy" "ecs_execution_db" {
  name = "read-db-password"
  role = var.execution_role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.db_password.arn
    }]
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "todo-${var.env}"
  subnet_ids = var.subnet_ids
  tags       = var.common_tags
}

resource "aws_security_group" "rds" {
  name   = "todo-${var.env}-rds"
  vpc_id = var.vpc_id

  ingress {
    description     = "PostgreSQL from backend tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.backend_sg_id]
  }

  # No egress rule — RDS never initiates outbound connections.
  # AWS RDS maintenance traffic uses internal AWS infrastructure, not this SG.

  tags = var.common_tags
}

resource "aws_db_instance" "main" {
  identifier        = "todo-${var.env}"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"

  db_name  = "todo"
  username = "todo"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  storage_encrypted       = true
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = var.common_tags
}
