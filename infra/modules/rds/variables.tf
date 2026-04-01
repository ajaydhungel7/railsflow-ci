variable "env"     { type = string }
variable "project" { type = string }
variable "vpc_id"  { type = string }

variable "private_subnets" { type = list(string) }

variable "db_name" {
  type    = string
  default = "shopstream"
}

variable "db_username" {
  type    = string
  default = "shopstream"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "multi_az" {
  type    = bool
  default = false
}
