variable "env" {
  type = string
}

variable "project" {
  type = string
}

variable "image_name" {
  type    = string
  default = "shopstream-api"
}

variable "retention_count" {
  type    = number
  default = 20
}
