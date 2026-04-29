output "db_host"         { value = aws_db_instance.main.address }
output "db_port"         { value = tostring(aws_db_instance.main.port) }
output "db_name"         { value = aws_db_instance.main.db_name }
output "db_user"         { value = aws_db_instance.main.username }
output "db_password_arn" { value = aws_secretsmanager_secret.db_password.arn }
