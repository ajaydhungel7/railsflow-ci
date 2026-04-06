# Environment-specific sizing and networking for qa.
# All other config (env name, project, region) is derived by root.hcl from the directory path.

locals {
  # VPC
  vpc_cidr        = "10.2.0.0/16"
  azs             = ["ca-central-1a", "ca-central-1b"]
  public_subnets  = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnets = ["10.2.10.0/24", "10.2.11.0/24"]

  # EKS — production-grade sizing
  node_instance_type = "t2.medium"
  node_desired_size  = 3
  node_min_size      = 2
  node_max_size      = 6

  # RDS — production-grade sizing with HA
  instance_class    = "db.t3.small"
  allocated_storage = 50
  multi_az          = true
}
