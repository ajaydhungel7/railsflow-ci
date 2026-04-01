include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  env     = "prod"
  project = "shopstream"
  region  = "ca-central-1"
  cidr            = "10.1.0.0/16"
  azs             = ["ca-central-1a", "ca-central-1b"]
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.10.0/24", "10.1.11.0/24"]
}
