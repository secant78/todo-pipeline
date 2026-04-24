variable "env"                 { type = string }
variable "aws_region"         { type = string }
variable "aws_account_id"     { type = string }
variable "backend_image_tag"  { type = string }
variable "frontend_image_tag" { type = string }
variable "cpu"                { type = number }
variable "memory"             { type = number }
variable "desired_count"      { type = number }
variable "vpc_cidr"           { type = string }
variable "availability_zones" { type = list(string) }
variable "github_repo"            { type = string }
variable "github_branch"          { type = string }
variable "deployment_config_name" { type = string }
variable "single_nat_gateway"     { type = bool; default = false }
