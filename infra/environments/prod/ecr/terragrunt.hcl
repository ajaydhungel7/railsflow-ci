include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
  env             = "prod"
  project         = "shopstream"
  retention_count = 30
}
