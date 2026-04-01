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
  env                = "prod"
  project            = "shopstream"
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnets    = dependency.vpc.outputs.private_subnets
  cluster_version    = "1.32"
  node_instance_type = "t2.medium"
  node_desired_size  = 3
  node_min_size      = 2
  node_max_size      = 6
}
