variable "env"                { type = string }
variable "vpc_cidr"           { type = string }
variable "availability_zones" { type = list(string) }
variable "single_nat_gateway" {
  type    = bool
  default = false
}
variable "common_tags"        { type = map(string) }
