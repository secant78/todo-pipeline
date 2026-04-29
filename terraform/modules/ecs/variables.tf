variable "env"                   { type = string }
variable "aws_region"           { type = string }
variable "ecr_region"           { type = string }
variable "aws_account_id"       { type = string }
variable "cpu"                  { type = number }
variable "memory"               { type = number }
variable "desired_count"        { type = number }
variable "backend_image_tag"    { type = string }
variable "frontend_image_tag"   { type = string }
variable "execution_role_arn"   { type = string }
variable "task_role_arn"        { type = string }
variable "subnet_ids"           { type = list(string) }
variable "backend_sg_id"        { type = string }
variable "frontend_sg_id"       { type = string }
variable "backend_tg_arn"       { type = string }
variable "frontend_tg_arn"      { type = string }
variable "jwt_secret_arn"       { type = string }
variable "db_host"              { type = string }
variable "db_port"              { type = string }
variable "db_name"              { type = string }
variable "db_user"              { type = string }
variable "db_password_arn"      { type = string }
variable "deployment_controller_type" {
  type    = string
  default = "CODE_DEPLOY"
}
variable "common_tags"          { type = map(string) }
