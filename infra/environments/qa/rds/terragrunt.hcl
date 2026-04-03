locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env               = include.root.locals.env
  project           = "shopstream"
  vpc_id            = dependency.vpc.outputs.vpc_id
  private_subnets   = dependency.vpc.outputs.private_subnets
  db_name           = "shopstream"
  db_username       = "shopstream"
  instance_class    = local.env_vars.locals.instance_class
  allocated_storage = local.env_vars.locals.allocated_storage
  multi_az          = local.env_vars.locals.multi_az
}
