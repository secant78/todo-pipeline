# JWT_SECRET_KEY is the only application secret at this scale.
# It lives in Secrets Manager — never in env files, source code, or task definition
# plaintext.  The ECS task execution role is given read access so the container
# can fetch it at startup without any application-level SDK calls.

resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "todo-${local.env}/jwt-secret-key"
  description = "JWT signing key for the ${local.env} todo app backend"

  # Secrets Manager keeps AWSCURRENT and AWSPREVIOUS versions automatically.
  # recovery_window_in_days = 0 means immediate deletion (useful for dev/CI teardowns).
  # In prod you'd set this to 7 or 30 to prevent accidental permanent deletion.
  recovery_window_in_days = local.env == "prod" ? 30 : 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  # Initial placeholder — the pipeline or an operator rotates this to a real value.
  # Using a placeholder here means Terraform doesn't store the real secret in state.
  secret_string = "REPLACE_ME_ON_FIRST_DEPLOY"

  # Ignore future changes so Terraform doesn't overwrite a rotated secret
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Automatic rotation every 30 days using the built-in SecretsManager rotation
# lambda for "plain text" secrets (no database credential rotation needed here).
resource "aws_secretsmanager_secret_rotation" "jwt_secret" {
  secret_id           = aws_secretsmanager_secret.jwt_secret.id
  rotation_lambda_arn = aws_lambda_function.secret_rotator.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# Minimal Lambda that generates a new random 64-byte hex secret and sets it
# as the AWSCURRENT version.  ECS will pick it up on the next task restart.
resource "aws_lambda_function" "secret_rotator" {
  function_name    = "todo-${local.env}-secret-rotator"
  role             = aws_iam_role.secret_rotator.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = "${path.module}/rotator.zip"
  source_code_hash = filebase64sha256("${path.module}/rotator.zip")
  timeout          = 30
  tags             = local.common_tags
}

# Allow Secrets Manager to invoke the rotation Lambda
resource "aws_lambda_permission" "secrets_manager" {
  statement_id  = "AllowSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secret_rotator.function_name
  principal     = "secretsmanager.amazonaws.com"
}
