output "alb_dns_name"          { value = module.networking.alb_dns_name }
output "ecs_cluster_name"      { value = module.ecs.cluster_name }
output "backend_service_name"  { value = module.ecs.backend_service_name }
output "frontend_service_name" { value = module.ecs.frontend_service_name }
output "jwt_secret_arn" {
  value     = module.secrets.jwt_secret_arn
  sensitive = true
}
