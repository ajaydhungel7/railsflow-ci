variable "env"     { type = string }
variable "project" { type = string }
variable "vpc_id"  { type = string }
variable "private_subnets" {
  type = list(string)
}
variable "cluster_version" {
  type    = string
  default = "1.32"
}
variable "node_instance_type" {
  type    = string
  default = "t2.medium"
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "node_min_size" {
  type    = number
  default = 1
}
variable "node_max_size" {
  type    = number
  default = 4
}
