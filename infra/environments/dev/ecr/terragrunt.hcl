include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
  env             = "dev"
  project         = "shopstream"
  retention_count = 10
}
