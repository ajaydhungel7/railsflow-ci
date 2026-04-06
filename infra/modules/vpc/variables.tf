variable "env"     { type = string }
variable "project" { type = string }
variable "region"  { type = string }

variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs"             { type = list(string) }
variable "public_subnets"  { type = list(string) }
variable "private_subnets" { type = list(string) }
