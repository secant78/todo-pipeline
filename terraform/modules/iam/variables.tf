variable "env"            { type = string }
variable "aws_region"     { type = string }
variable "aws_account_id" { type = string }
variable "github_repo"    { type = string }   # e.g. "secant78/todo-pipeline"
variable "github_branch"  { type = string }   # "dev", "staging", or "main"
variable "common_tags"    { type = map(string) }
