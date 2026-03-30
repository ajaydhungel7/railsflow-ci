# Terraform + Terragrunt Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build production-grade AWS infrastructure for ShopStream using Terraform modules and Terragrunt environments, provisioning only the dev environment.

**Architecture:** Five Terraform modules (vpc, ecr, eks, rds, iam) live under `infra/modules/`. Terragrunt wires them together per environment via `infra/environments/dev/` and `infra/environments/prod/`, sharing a root `terragrunt.hcl` that configures S3 remote state and the AWS provider. Only `dev` gets `terragrunt apply`; `prod` is structure-only.

**Tech Stack:** Terraform ~> 1.12, Terragrunt ~> 0.77, AWS provider ~> 5.95, EKS 1.32 with EC2 managed node groups, RDS PostgreSQL 16, ECR, S3 native state locking (no DynamoDB).

---

## Prerequisites

- AWS CLI configured (`aws configure`) with an account you control
- Terraform >= 1.12 installed (`brew install terraform`) — required for S3 native state locking
- Terragrunt >= 0.77 installed (`brew install terragrunt`)
- An S3 bucket for remote state (Task 1 bootstraps this — no DynamoDB needed)

---

## Directory Layout

```
infra/
├── terragrunt.hcl                        ← root: S3 backend + AWS provider block
├── bootstrap/
│   └── main.tf                           ← one-time: creates S3 bucket for state (native locking)
├── modules/
│   ├── vpc/
│   │   ├── main.tf                       ← VPC, subnets, IGW, NAT, route tables
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecr/
│   │   ├── main.tf                       ← ECR repo, lifecycle policy
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/
│   │   ├── main.tf                       ← EKS cluster, EC2 managed node group, OIDC
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── rds/
│   │   ├── main.tf                       ← RDS PostgreSQL, subnet group, SG
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/
│       ├── main.tf                       ← GitHub Actions OIDC role + policies
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── terragrunt.hcl                    ← shared: account_id, region, env inputs
    ├── dev/
    │   ├── terragrunt.hcl                ← dev-specific: small instance sizes
    │   ├── vpc/terragrunt.hcl
    │   ├── ecr/terragrunt.hcl
    │   ├── eks/terragrunt.hcl
    │   ├── rds/terragrunt.hcl
    │   └── iam/terragrunt.hcl
    └── prod/
        ├── terragrunt.hcl                ← prod-specific: larger sizes, multi-AZ
        ├── vpc/terragrunt.hcl
        ├── ecr/terragrunt.hcl
        ├── eks/terragrunt.hcl
        ├── rds/terragrunt.hcl
        └── iam/terragrunt.hcl
```

---

## Task 1: Bootstrap Remote State

**Files:**
- Create: `infra/bootstrap/main.tf`

Remote state must exist before Terragrunt can run. This is a one-time standalone Terraform apply, not managed by Terragrunt.

- [ ] **Step 1: Write bootstrap Terraform**

```hcl
# infra/bootstrap/main.tf
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "ca-central-1"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket = "shopstream-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# S3 Object Ownership — required for native state locking (conditional writes)
resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

output "bucket_name" { value = aws_s3_bucket.tfstate.bucket }
```

- [ ] **Step 2: Apply bootstrap**

```bash
cd infra/bootstrap
terraform init
terraform apply
# Note the bucket_name output — you'll need it in Task 2
```

Expected output:
```
bucket_name = "shopstream-tfstate-<account-id>"
```

- [ ] **Step 3: Commit**

```bash
git add infra/bootstrap/main.tf
git commit -m "infra: add remote state bootstrap"
```

---

## Task 2: Root Terragrunt Config

**Files:**
- Create: `infra/terragrunt.hcl`

The root config defines remote state and the AWS provider for all child modules.

- [ ] **Step 1: Write root terragrunt.hcl**

Replace `<account-id>` with the value from Task 1 output.

```hcl
# infra/terragrunt.hcl
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
    use_lockfile = true   # S3 native locking — no DynamoDB needed (requires Terraform >= 1.10)
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = {
      Project     = "shopstream"
      ManagedBy   = "terraform"
      Environment = "${local.env}"
    }
  }
}
EOF
}
```

- [ ] **Step 2: Write shared environments config**

```hcl
# infra/environments/terragrunt.hcl
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
```

- [ ] **Step 3: Commit**

```bash
git add infra/terragrunt.hcl infra/environments/terragrunt.hcl
git commit -m "infra: add root and environments terragrunt config"
```

---

## Task 3: VPC Module

**Files:**
- Create: `infra/modules/vpc/main.tf`
- Create: `infra/modules/vpc/variables.tf`
- Create: `infra/modules/vpc/outputs.tf`

2 AZs, public + private subnets, single NAT gateway (dev — cost-conscious).

- [ ] **Step 1: Write variables.tf**

```hcl
# infra/modules/vpc/variables.tf
variable "env"     { type = string }
variable "project" { type = string }
variable "region"  { type = string }

variable "cidr"            { type = string; default = "10.0.0.0/16" }
variable "azs"             { type = list(string) }
variable "public_subnets"  { type = list(string) }
variable "private_subnets" { type = list(string) }
```

- [ ] **Step 2: Write main.tf**

```hcl
# infra/modules/vpc/main.tf
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.project}-${var.env}" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project}-${var.env}-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                                              = "${var.project}-${var.env}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${var.project}-${var.env}" = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name                                              = "${var.project}-${var.env}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"                 = "1"
    "kubernetes.io/cluster/${var.project}-${var.env}" = "shared"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project}-${var.env}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.project}-${var.env}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.this.id }
  tags = { Name = "${var.project}-${var.env}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0"; nat_gateway_id = aws_nat_gateway.this.id }
  tags = { Name = "${var.project}-${var.env}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

- [ ] **Step 3: Write outputs.tf**

```hcl
# infra/modules/vpc/outputs.tf
output "vpc_id"          { value = aws_vpc.this.id }
output "public_subnets"  { value = aws_subnet.public[*].id }
output "private_subnets" { value = aws_subnet.private[*].id }
output "vpc_cidr"        { value = aws_vpc.this.cidr_block }
```

- [ ] **Step 4: Write dev Terragrunt config**

```hcl
# infra/environments/dev/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  env     = "dev"
  project = "shopstream"
  region  = "ca-central-1"
  azs             = ["ca-central-1a", "ca-central-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
}
```

- [ ] **Step 5: Write prod Terragrunt config (structure only — do not apply)**

```hcl
# infra/environments/prod/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  env     = "prod"
  project = "shopstream"
  region  = "ca-central-1"
  azs             = ["ca-central-1a", "ca-central-1b"]
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.10.0/24", "10.1.11.0/24"]
}
```

- [ ] **Step 6: Validate and apply dev VPC**

```bash
cd infra/environments/dev/vpc
terragrunt validate
terragrunt plan   # Review: should show VPC, 4 subnets, IGW, NAT, route tables
terragrunt apply
```

Expected: ~10 resources created including `vpc_id` output.

- [ ] **Step 7: Commit**

```bash
git add infra/modules/vpc/ infra/environments/dev/vpc/ infra/environments/prod/vpc/
git commit -m "infra: add VPC module and dev/prod configs"
```

---

## Task 4: ECR Module

**Files:**
- Create: `infra/modules/ecr/main.tf`
- Create: `infra/modules/ecr/variables.tf`
- Create: `infra/modules/ecr/outputs.tf`
- Create: `infra/environments/dev/ecr/terragrunt.hcl`
- Create: `infra/environments/prod/ecr/terragrunt.hcl`

ECR has no VPC dependency — can apply independently.

- [ ] **Step 1: Write variables.tf**

```hcl
# infra/modules/ecr/variables.tf
variable "env"            { type = string }
variable "project"        { type = string }
variable "image_name"     { type = string; default = "shopstream-api" }
variable "retention_count" { type = number; default = 20 }
```

- [ ] **Step 2: Write main.tf**

```hcl
# infra/modules/ecr/main.tf
resource "aws_ecr_repository" "this" {
  name                 = "${var.project}-${var.image_name}-${var.env}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "${var.project}-${var.image_name}-${var.env}" }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.retention_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.retention_count
      }
      action = { type = "expire" }
    }]
  })
}
```

- [ ] **Step 3: Write outputs.tf**

```hcl
# infra/modules/ecr/outputs.tf
output "repository_url"  { value = aws_ecr_repository.this.repository_url }
output "repository_name" { value = aws_ecr_repository.this.name }
output "registry_id"     { value = aws_ecr_repository.this.registry_id }
```

- [ ] **Step 4: Write dev and prod Terragrunt configs**

```hcl
# infra/environments/dev/ecr/terragrunt.hcl
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../modules/ecr" }
inputs = { env = "dev"; project = "shopstream"; retention_count = 10 }
```

```hcl
# infra/environments/prod/ecr/terragrunt.hcl
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../modules/ecr" }
inputs = { env = "prod"; project = "shopstream"; retention_count = 30 }
```

- [ ] **Step 5: Apply dev ECR**

```bash
cd infra/environments/dev/ecr
terragrunt apply
```

Expected output:
```
repository_url = "<account-id>.dkr.ecr.ca-central-1.amazonaws.com/shopstream-shopstream-api-dev"
```

- [ ] **Step 6: Commit**

```bash
git add infra/modules/ecr/ infra/environments/dev/ecr/ infra/environments/prod/ecr/
git commit -m "infra: add ECR module and dev/prod configs"
```

---

## Task 5: EKS Module

**Files:**
- Create: `infra/modules/eks/main.tf`
- Create: `infra/modules/eks/variables.tf`
- Create: `infra/modules/eks/outputs.tf`
- Create: `infra/environments/dev/eks/terragrunt.hcl`
- Create: `infra/environments/prod/eks/terragrunt.hcl`

Depends on VPC. EKS with EC2 managed node group — real nodes visible immediately, easier to debug than Fargate.

- [ ] **Step 1: Write variables.tf**

```hcl
# infra/modules/eks/variables.tf
variable "env"             { type = string }
variable "project"         { type = string }
variable "vpc_id"          { type = string }
variable "private_subnets" { type = list(string) }
variable "cluster_version" { type = string; default = "1.32" }
variable "node_instance_type" { type = string; default = "t2.medium" }
variable "node_desired_size"  { type = number; default = 2 }
variable "node_min_size"      { type = number; default = 1 }
variable "node_max_size"      { type = number; default = 4 }
```

- [ ] **Step 2: Write main.tf**

```hcl
# infra/modules/eks/main.tf
data "aws_caller_identity" "current" {}

# --- Cluster IAM Role ---
resource "aws_iam_role" "cluster" {
  name = "${var.project}-${var.env}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- EKS Cluster ---
resource "aws_eks_cluster" "this" {
  name     = "${var.project}-${var.env}"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# --- Node Group IAM Role ---
resource "aws_iam_role" "nodes" {
  name = "${var.project}-${var.env}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- EC2 Managed Node Group ---
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project}-${var.env}-default"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnets
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config { max_unavailable = 1 }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
  ]
}

# --- OIDC Provider for IRSA (IAM Roles for Service Accounts) ---
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
```

- [ ] **Step 3: Write outputs.tf**

```hcl
# infra/modules/eks/outputs.tf
output "cluster_name"      { value = aws_eks_cluster.this.name }
output "cluster_endpoint"  { value = aws_eks_cluster.this.endpoint }
output "cluster_ca"        { value = aws_eks_cluster.this.certificate_authority[0].data }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.eks.arn }
output "oidc_issuer_url"   { value = aws_eks_cluster.this.identity[0].oidc[0].issuer }
output "node_role_arn"     { value = aws_iam_role.nodes.arn }
```

- [ ] **Step 4: Write dev Terragrunt config (with dependency on VPC)**

```hcl
# infra/environments/dev/eks/terragrunt.hcl
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../modules/eks" }

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env                = "dev"
  project            = "shopstream"
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnets    = dependency.vpc.outputs.private_subnets
  cluster_version    = "1.32"
  node_instance_type = "t2.medium"
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 3
}
```

- [ ] **Step 5: Write prod Terragrunt config**

```hcl
# infra/environments/prod/eks/terragrunt.hcl
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../modules/eks" }

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env                = "prod"
  project            = "shopstream"
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnets    = dependency.vpc.outputs.private_subnets
  cluster_version    = "1.32"
  node_instance_type = "t2.medium"
  node_desired_size  = 3
  node_min_size      = 2
  node_max_size      = 6
}
```

- [ ] **Step 6: Apply dev EKS (takes ~12 minutes)**

```bash
cd infra/environments/dev/eks
terragrunt apply
```

Expected: EKS cluster + managed node group created. Outputs include `cluster_name` and `oidc_provider_arn`.

- [ ] **Step 7: Update kubeconfig to verify**

```bash
aws eks update-kubeconfig --name shopstream-dev --region ca-central-1
kubectl get nodes
```

Expected: 2 EC2 nodes in `Ready` state (e.g. `ip-10-0-10-x.ec2.internal`).

- [ ] **Step 8: Commit**

```bash
git add infra/modules/eks/ infra/environments/dev/eks/ infra/environments/prod/eks/
git commit -m "infra: add EKS module with Fargate profile and OIDC"
```

---

## Task 6: RDS Module

**Files:**
- Create: `infra/modules/rds/main.tf`
- Create: `infra/modules/rds/variables.tf`
- Create: `infra/modules/rds/outputs.tf`
- Create: `infra/environments/dev/rds/terragrunt.hcl`
- Create: `infra/environments/prod/rds/terragrunt.hcl`

PostgreSQL 14 on RDS in private subnets. Dev uses `db.t3.micro`, no multi-AZ.

- [ ] **Step 1: Write variables.tf**

```hcl
# infra/modules/rds/variables.tf
variable "env"             { type = string }
variable "project"         { type = string }
variable "vpc_id"          { type = string }
variable "private_subnets" { type = list(string) }
variable "vpc_cidr"        { type = string }

variable "instance_class"  { type = string; default = "db.t2.micro" }
variable "db_name"         { type = string; default = "shopstream_production" }
variable "db_username"     { type = string; default = "shopstream" }
variable "db_password"     { type = string; sensitive = true }
variable "multi_az"        { type = bool; default = false }
variable "storage_gb"      { type = number; default = 20 }
```

- [ ] **Step 2: Write main.tf**

```hcl
# infra/modules/rds/main.tf
resource "aws_security_group" "rds" {
  name   = "${var.project}-${var.env}-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.env}-rds-sg" }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.env}-db-subnet-group"
  subnet_ids = var.private_subnets
  tags       = { Name = "${var.project}-${var.env}-db-subnet-group" }
}

resource "aws_db_instance" "this" {
  identifier        = "${var.project}-${var.env}"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.instance_class
  allocated_storage = var.storage_gb
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = var.multi_az
  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "${var.project}-${var.env}-postgres" }
}
```

- [ ] **Step 3: Write outputs.tf**

```hcl
# infra/modules/rds/outputs.tf
output "endpoint"    { value = aws_db_instance.this.endpoint }
output "db_name"     { value = aws_db_instance.this.db_name }
output "db_username" { value = aws_db_instance.this.username }
output "database_url" {
  value     = "postgres://${aws_db_instance.this.username}:${var.db_password}@${aws_db_instance.this.endpoint}/${aws_db_instance.this.db_name}"
  sensitive = true
}
```

- [ ] **Step 4: Write dev Terragrunt config**

The DB password comes from an environment variable — never hardcoded.

```hcl
# infra/environments/dev/rds/terragrunt.hcl
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../modules/rds" }

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock-1", "subnet-mock-2"]
    vpc_cidr        = "10.0.0.0/16"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env             = "dev"
  project         = "shopstream"
  vpc_id          = dependency.vpc.outputs.vpc_id
  private_subnets = dependency.vpc.outputs.private_subnets
  vpc_cidr        = dependency.vpc.outputs.vpc_cidr
  instance_class  = "db.t2.micro"
  multi_az        = false
  db_password     = get_env("TF_VAR_db_password")
}
```

- [ ] **Step 5: Write prod Terragrunt config**

```hcl
# infra/environments/prod/rds/terragrunt.hcl
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../modules/rds" }

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock-1", "subnet-mock-2"]
    vpc_cidr        = "10.1.0.0/16"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env             = "prod"
  project         = "shopstream"
  vpc_id          = dependency.vpc.outputs.vpc_id
  private_subnets = dependency.vpc.outputs.private_subnets
  vpc_cidr        = dependency.vpc.outputs.vpc_cidr
  instance_class  = "db.t2.medium"
  multi_az        = true
  db_password     = get_env("TF_VAR_db_password")
}
```

- [ ] **Step 6: Apply dev RDS (takes ~5 minutes)**

```bash
export TF_VAR_db_password="$(openssl rand -base64 24)"
echo "Save this password: $TF_VAR_db_password"  # store in AWS Secrets Manager or 1Password

cd infra/environments/dev/rds
terragrunt apply
```

Expected: RDS instance created with endpoint like `shopstream-dev.xxxx.ca-central-1.rds.amazonaws.com:5432`.

- [ ] **Step 7: Commit**

```bash
git add infra/modules/rds/ infra/environments/dev/rds/ infra/environments/prod/rds/
git commit -m "infra: add RDS PostgreSQL module and dev/prod configs"
```

---

## Task 7: IAM Module (GitHub Actions OIDC)

**Files:**
- Create: `infra/modules/iam/main.tf`
- Create: `infra/modules/iam/variables.tf`
- Create: `infra/modules/iam/outputs.tf`
- Create: `infra/environments/dev/iam/terragrunt.hcl`
- Create: `infra/environments/prod/iam/terragrunt.hcl`

Creates an IAM role that GitHub Actions assumes via OIDC — no long-lived credentials.

- [ ] **Step 1: Write variables.tf**

```hcl
# infra/modules/iam/variables.tf
variable "env"              { type = string }
variable "project"          { type = string }
variable "account_id"       { type = string }
variable "oidc_provider_arn" { type = string }
variable "github_org"       { type = string }
variable "github_repo"      { type = string }
variable "ecr_repository_arn" { type = string }
variable "eks_cluster_name"   { type = string }
```

- [ ] **Step 2: Write main.tf**

```hcl
# infra/modules/iam/main.tf
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project}-${var.env}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

data "aws_iam_policy_document" "github_permissions" {
  statement {
    sid     = "ECRAuth"
    actions = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "ECRPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }
  statement {
    sid = "EKSDeploy"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = ["arn:aws:eks:*:${var.account_id}:cluster/${var.eks_cluster_name}"]
  }
}

resource "aws_iam_policy" "github_permissions" {
  name   = "${var.project}-${var.env}-github-actions-policy"
  policy = data.aws_iam_policy_document.github_permissions.json
}

resource "aws_iam_role_policy_attachment" "github_permissions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_permissions.arn
}
```

- [ ] **Step 3: Write outputs.tf**

```hcl
# infra/modules/iam/outputs.tf
output "github_actions_role_arn" { value = aws_iam_role.github_actions.arn }
```

- [ ] **Step 4: Write dev Terragrunt config**

Replace `your-github-org` with your actual GitHub org/username.

```hcl
# infra/environments/dev/iam/terragrunt.hcl
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../modules/iam" }

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::123456789:oidc-provider/mock"
    cluster_name      = "shopstream-dev"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "ecr" {
  config_path = "../ecr"
  mock_outputs = { repository_url = "mock.ecr.url"; registry_id = "123456789" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env               = "dev"
  project           = "shopstream"
  account_id        = get_aws_account_id()
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  github_org        = "your-github-org"
  github_repo       = "railsflow-ci"
  ecr_repository_arn = "arn:aws:ecr:ca-central-1:${get_aws_account_id()}:repository/${dependency.ecr.outputs.repository_name}"
  eks_cluster_name  = dependency.eks.outputs.cluster_name
}
```

- [ ] **Step 5: Write prod Terragrunt config**

```hcl
# infra/environments/prod/iam/terragrunt.hcl
include "root" { path = find_in_parent_folders() }
terraform { source = "../../../modules/iam" }

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::123456789:oidc-provider/mock"
    cluster_name      = "shopstream-prod"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "ecr" {
  config_path = "../ecr"
  mock_outputs = { repository_url = "mock.ecr.url"; registry_id = "123456789" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  env               = "prod"
  project           = "shopstream"
  account_id        = get_aws_account_id()
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  github_org        = "your-github-org"
  github_repo       = "railsflow-ci"
  ecr_repository_arn = "arn:aws:ecr:ca-central-1:${get_aws_account_id()}:repository/${dependency.ecr.outputs.repository_name}"
  eks_cluster_name  = dependency.eks.outputs.cluster_name
}
```

- [ ] **Step 6: Apply dev IAM**

```bash
cd infra/environments/dev/iam
terragrunt apply
```

Expected output:
```
github_actions_role_arn = "arn:aws:iam::<account-id>:role/shopstream-dev-github-actions"
```

Save this ARN — it goes into GitHub Actions secrets as `AWS_ROLE_ARN`.

- [ ] **Step 7: Commit**

```bash
git add infra/modules/iam/ infra/environments/dev/iam/ infra/environments/prod/iam/
git commit -m "infra: add IAM OIDC role for GitHub Actions"
```

---

## Task 8: Validate Full Dev Stack

- [ ] **Step 1: Run plan across all dev modules**

```bash
cd infra/environments/dev
terragrunt run-all plan
```

Expected: All 5 modules show no changes (everything already applied).

- [ ] **Step 2: Verify cluster access**

```bash
aws eks update-kubeconfig --name shopstream-dev --region ca-central-1
kubectl get namespaces
```

Expected: `default`, `kube-system` namespaces listed.

- [ ] **Step 3: Verify ECR**

```bash
aws ecr describe-repositories --region ca-central-1 | jq '.repositories[].repositoryName'
```

Expected: `"shopstream-shopstream-api-dev"`

- [ ] **Step 4: Verify OIDC role**

```bash
aws iam get-role --role-name shopstream-dev-github-actions | jq '.Role.AssumeRolePolicyDocument'
```

Expected: Trust policy shows `token.actions.githubusercontent.com` as the federated principal.

- [ ] **Step 5: Final commit**

```bash
git add .
git commit -m "infra: complete dev environment provisioning"
```

---

## Prod Structure Verification (no apply)

```bash
cd infra/environments/prod
terragrunt run-all validate
```

Expected: All modules validate successfully (using mock outputs for dependencies).

---

## Key Outputs to Save (for GitHub Actions secrets)

After Task 8, collect these values:

```bash
# ECR repo URL
cd infra/environments/dev/ecr && terragrunt output repository_url

# EKS cluster name
cd infra/environments/dev/eks && terragrunt output cluster_name

# GitHub Actions IAM role ARN
cd infra/environments/dev/iam && terragrunt output github_actions_role_arn

# RDS database URL (sensitive)
cd infra/environments/dev/rds && terragrunt output database_url
```

These become GitHub Actions secrets: `ECR_REPOSITORY`, `EKS_CLUSTER_NAME`, `AWS_ROLE_ARN`, `DATABASE_URL`.
