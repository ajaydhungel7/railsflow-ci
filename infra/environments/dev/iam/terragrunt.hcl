include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/iam"
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name      = "shopstream-dev-mock"
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

inputs = {
  env               = "dev"
  project           = "shopstream"
  github_org        = "ajaydhungel7"
  github_repo       = "shopstream-api"
  eks_cluster_name  = dependency.eks.outputs.cluster_name
  ecr_arn           = dependency.ecr.outputs.repository_arn
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_issuer_url   = dependency.eks.outputs.oidc_issuer_url
}
