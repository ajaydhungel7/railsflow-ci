terraform_binary = "terraform"

locals {
  account_id = get_aws_account_id()
  region     = "ca-central-1"
}

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
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = {
      Project   = "shopstream"
      ManagedBy = "terraform"
    }
  }
}
EOF
}
