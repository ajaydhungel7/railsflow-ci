resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ── GitHub Actions deploy role ────────────────────────────────────────────────

resource "aws_iam_role" "github_actions_deploy" {
  name = "${var.project}-${var.env}-github-actions-deploy"
  tags = { Name = "${var.project}-${var.env}-github-actions-deploy" }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "ecr" {
  name = "${var.project}-${var.env}-ecr-access"
  tags = { Name = "${var.project}-${var.env}-ecr-access" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = var.ecr_arn
      },
    ]
  })
}

resource "aws_iam_policy" "eks" {
  name = "${var.project}-${var.env}-eks-deploy"
  tags = { Name = "${var.project}-${var.env}-eks-deploy" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = "arn:aws:eks:*:*:cluster/${var.eks_cluster_name}"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.ecr.arn
}

resource "aws_iam_role_policy_attachment" "eks" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.eks.arn
}

# ── ALB controller IRSA role ──────────────────────────────────────────────────

locals {
  oidc_issuer = trimprefix(var.oidc_issuer_url, "https://")
}

resource "aws_iam_role" "alb_controller" {
  name = "${var.project}-${var.env}-alb-controller"
  tags = { Name = "${var.project}-${var.env}-alb-controller" }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.project}-${var.env}-alb-controller"
  tags   = { Name = "${var.project}-${var.env}-alb-controller" }
  policy = file("${path.module}/alb-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# ── External Secrets Operator IRSA role ───────────────────────────────────────

resource "aws_iam_role" "external_secrets" {
  name = "${var.project}-${var.env}-external-secrets"
  tags = { Name = "${var.project}-${var.env}-external-secrets" }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "external_secrets" {
  name = "${var.project}-${var.env}-external-secrets"
  tags = { Name = "${var.project}-${var.env}-external-secrets" }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = var.db_secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}
