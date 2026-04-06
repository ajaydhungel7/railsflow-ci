# Environment-specific sizing and networking for dev.
# All other config (env name, project, region) is derived by root.hcl from the directory path.

locals {
  # VPC
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["ca-central-1a", "ca-central-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]

  # EKS
  node_instance_type = "t2.medium"
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 3

  # RDS
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  multi_az          = false
}
