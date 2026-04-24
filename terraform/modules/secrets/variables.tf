variable "env"               { type = string }
variable "aws_region"       { type = string }
variable "aws_account_id"   { type = string }
variable "rotator_role_arn" { type = string }
variable "rotator_role_id"  { type = string }
variable "execution_role_id" { type = string }
variable "rotator_zip_path" { type = string }
variable "common_tags"      { type = map(string) }
