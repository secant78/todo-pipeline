variable "env"              { type = string }
variable "vpc_id"           { type = string }
variable "subnet_ids"       { type = list(string) }
variable "backend_sg_id"    { type = string }
variable "execution_role_id" { type = string }
variable "common_tags"      { type = map(string) }

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}
