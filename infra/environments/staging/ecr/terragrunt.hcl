include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
  env             = include.root.locals.env
  project         = "shopstream"
  retention_count = 10
}
