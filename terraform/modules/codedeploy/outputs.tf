output "backend_app_name"    { value = aws_codedeploy_app.backend.name }
output "frontend_app_name"   { value = aws_codedeploy_app.frontend.name }
output "backend_group_name"  { value = aws_codedeploy_deployment_group.backend.deployment_group_name }
output "frontend_group_name" { value = aws_codedeploy_deployment_group.frontend.deployment_group_name }
