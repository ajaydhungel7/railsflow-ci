include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../modules/iam"
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name      = "shopstream-mock"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ca-central-1.amazonaws.com/id/MOCK"
    oidc_issuer_url   = "https://oidc.eks.ca-central-1.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "ecr" {
  config_path = "../ecr"
  mock_outputs = {
    repository_arn = "arn:aws:ecr:ca-central-1:123456789012:repository/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "rds" {
  config_path = "../rds"
  mock_outputs = {
    db_password_secret_arn = "arn:aws:secretsmanager:ca-central-1:123456789012:secret:mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env               = include.root.locals.env
  project           = "shopstream"
  github_org        = "ajaydhungel7"
  github_repo       = "railsflow-ci"
  eks_cluster_name  = dependency.eks.outputs.cluster_name
  ecr_arn           = dependency.ecr.outputs.repository_arn
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_issuer_url   = dependency.eks.outputs.oidc_issuer_url
  db_secret_arn     = dependency.rds.outputs.db_password_secret_arn
}
