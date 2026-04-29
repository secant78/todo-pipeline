variable "env"        { type = string }
variable "subnet_ids" { type = list(string) }
variable "efs_sg_id"  { type = string }
variable "common_tags" { type = map(string) }
