locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks"
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
  env                = include.root.locals.env
  project            = "shopstream"
  private_subnets    = dependency.vpc.outputs.private_subnets
  cluster_version    = "1.32"
  node_instance_type = local.env_vars.locals.node_instance_type
  node_desired_size  = local.env_vars.locals.node_desired_size
  node_min_size      = local.env_vars.locals.node_min_size
  node_max_size      = local.env_vars.locals.node_max_size
}
