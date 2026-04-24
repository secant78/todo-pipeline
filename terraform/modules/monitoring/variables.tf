variable "env"                  { type = string }
variable "aws_region"          { type = string }
variable "memory"              { type = number }
variable "cluster_name"        { type = string }
variable "backend_service_name" { type = string }
variable "alb_arn_suffix"      { type = string }
variable "backend_tg_arn_suffix" { type = string }
variable "common_tags"         { type = map(string) }
