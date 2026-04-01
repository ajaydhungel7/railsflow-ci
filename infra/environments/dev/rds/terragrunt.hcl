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
  env               = "dev"
  project           = "shopstream"
  vpc_id            = dependency.vpc.outputs.vpc_id
  private_subnets   = dependency.vpc.outputs.private_subnets
  db_name           = "shopstream"
  db_username       = "shopstream"
  db_password       = get_env("TF_VAR_db_password", "changeme-dev")
  instance_class    = "db.t3.micro"
  allocated_storage = 20
}
