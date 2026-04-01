variable "env"     { type = string }
variable "project" { type = string }

variable "github_org" {
  type        = string
  description = "GitHub organisation name"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g. shopstream-api)"
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name to scope deploy permissions"
}

variable "ecr_arn" {
  type        = string
  description = "ECR repository ARN to scope push/pull permissions"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN (output of eks module) — used for ALB controller IRSA"
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS OIDC issuer URL (output of eks module) — used to build IRSA trust condition"
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for the RDS master password — scoped in ESO policy"
}
