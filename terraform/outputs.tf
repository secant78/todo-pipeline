output "alb_dns_name" {
  description = "Public DNS name of the ALB — the URL used to reach the app"
  value       = aws_lb.main.dns_name
}

output "backend_ecr_url" {
  description = "ECR repository URL for the backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_url" {
  description = "ECR repository URL for the frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name — used by the pipeline's rollback step"
  value       = aws_ecs_cluster.main.name
}

output "backend_service_name" {
  description = "ECS service name for the backend — used by the pipeline's rollback step"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "ECS service name for the frontend — used by the pipeline's rollback step"
  value       = aws_ecs_service.frontend.name
}
