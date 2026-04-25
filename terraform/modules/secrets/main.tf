resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "todo-${var.env}/jwt-secret-key"
  description             = "JWT signing key for the ${var.env} todo app backend"
  recovery_window_in_days = var.env == "prod" ? 30 : 0
  tags                    = var.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = "REPLACE_ME_ON_FIRST_DEPLOY"
  lifecycle { ignore_changes = [secret_string] }
}

# Rotation is prod-only — the Lambda/permission setup causes reliable
# failures in dev due to the test-rotation race with AddPermission.
resource "aws_lambda_function" "secret_rotator" {
  count            = var.env == "prod" ? 1 : 0
  function_name    = "todo-${var.env}-secret-rotator"
  role             = var.rotator_role_arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = var.rotator_zip_path
  source_code_hash = filebase64sha256(var.rotator_zip_path)
  timeout          = 30
  tags             = var.common_tags
}

resource "aws_lambda_permission" "secrets_manager" {
  count         = var.env == "prod" ? 1 : 0
  statement_id  = "AllowSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secret_rotator[0].function_name
  principal     = "secretsmanager.amazonaws.com"
}

resource "aws_secretsmanager_secret_rotation" "jwt_secret" {
  count               = var.env == "prod" ? 1 : 0
  secret_id           = aws_secretsmanager_secret.jwt_secret.id
  rotation_lambda_arn = aws_lambda_function.secret_rotator[0].arn
  rotation_rules { automatically_after_days = 30 }
}

# Allow the ECS execution role to read the JWT secret so it can inject it
# into the container environment at task start.
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "read-jwt-secret"
  role = var.execution_role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.jwt_secret.arn
    }]
  })
}

# Allow the rotation Lambda to manage the secret versions.
resource "aws_iam_role_policy" "secret_rotator_sm" {
  name = "rotate-jwt-secret"
  role = var.rotator_role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage",
      ]
      Resource = aws_secretsmanager_secret.jwt_secret.arn
    }]
  })
}
