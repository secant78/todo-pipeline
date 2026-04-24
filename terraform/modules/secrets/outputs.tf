output "jwt_secret_arn"  { value = aws_secretsmanager_secret.jwt_secret.arn }
output "jwt_secret_name" { value = aws_secretsmanager_secret.jwt_secret.name }
