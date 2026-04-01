terraform_binary = "terraform"

locals {
  account_id = get_aws_account_id()
  region     = "ca-central-1"

  # Derive env from path: environments/dev/vpc -> "dev"
  path_parts = split("/", path_relative_to_include())
  env        = length(local.path_parts) >= 2 ? local.path_parts[1] : "global"
}

# Single shared cache — prevents per-module cache sprawl and stale OpenTofu dirs
download_dir = "${get_home_dir()}/.terragrunt-cache/shopstream"

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = "shopstream-tfstate-${local.account_id}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.14"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 5.100.0" }
  }
}

provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = {
      Project     = "shopstream"
      Environment = "${local.env}"
      ManagedBy   = "terraform"
    }
  }
}
EOF
}
