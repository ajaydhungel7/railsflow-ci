locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  env     = include.root.locals.env
  project = "shopstream"
  region  = include.root.locals.region
  cidr            = local.env_vars.locals.vpc_cidr
  azs             = local.env_vars.locals.azs
  public_subnets  = local.env_vars.locals.public_subnets
  private_subnets = local.env_vars.locals.private_subnets
}
