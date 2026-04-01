locals {
  env        = basename(get_terragrunt_dir())
  account_id = get_aws_account_id()
  region     = "ca-central-1"
}

inputs = {
  env        = local.env
  account_id = local.account_id
  region     = local.region
  project    = "shopstream"
}
