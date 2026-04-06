# RailsFlow CI

A production-grade CI/CD pipeline reference implementation for Ruby on Rails, built entirely on GitHub Actions. Demonstrates real-world DevOps practices: branch-based promotion, canary deployments, infrastructure as code, security scanning, and automated rollback.

The fictional app being shipped is **ShopStream** — a Rails e-commerce API.

---

## Pipeline Overview

Code is written on `dev`, tested and built once, then promoted through staging to production — never rebuilt.

```
feature branch
  └── merge to dev
        └── CI — test · lint · security scan · build image → deploy dev
              └── merge dev → staging
                    └── promote :dev image → deploy staging
                          └── PR staging → main (merge)
                                └── promote :staging image → canary deploy prod (10%)
                                      ├── healthy → full rollout
                                      └── unhealthy → auto rollback
```

**The image built on `dev` is the exact binary that reaches production.**

---

## Features

| Feature | Detail |
|---|---|
| **Branch-based promotion** | `dev` → `staging` → `main` — each branch has its own scoped workflows |
| **Build once** | Docker image built and tested on `dev`, promoted via ECR tag retag — no rebuilds |
| **Security scanning** | Trivy (container CVEs) + Brakeman (Rails static analysis) block the pipeline on failure |
| **Canary deployment** | Production gets 10% traffic first, monitored for 10 min, auto-rollback on elevated errors |
| **Infrastructure as code** | AWS infrastructure managed with Terraform + Terragrunt — one module set, three environments |
| **OIDC auth** | No long-lived AWS credentials — GitHub Actions uses OIDC to assume IAM roles |
| **Slack notifications** | Every pipeline event (success, failure, rollback) posts to Slack |
| **Rollback** | Manual or automatic — redeploys any known-good image tag to any environment |
| **Branch protection** | Direct pushes blocked on all branches; workflow file changes require CODEOWNERS approval |

---

## Tech Stack

| Layer | Tool |
|---|---|
| CI/CD | GitHub Actions (Reusable Workflows, Environments, OIDC) |
| Infrastructure | Terraform + Terragrunt |
| Cloud | AWS (EKS, RDS, ECR, Secrets Manager, IAM) |
| Security | Trivy + Brakeman |
| Deployment | Kubernetes + Helm |
| Notifications | Slack Incoming Webhooks |
| App | Ruby on Rails |

---

## Repository Structure

```
railsflow-ci/
├── .github/
│   ├── CODEOWNERS                       # Protects workflow files from unauthorized changes
│   └── workflows/
│       ├── ci.yml                       # CI — test · build · deploy dev (dev branch only)
│       ├── staging.yml                  # Promote dev image → staging (staging branch only)
│       ├── prod.yml                     # Promote staging image → prod canary (main branch only)
│       ├── infra-plan.yml               # Terragrunt plan — auto on push, manual with env dropdown
│       ├── infra-apply.yml              # Terragrunt apply + install controllers — manual only
│       ├── deploy.yml                   # Reusable: migrate + Helm rollout
│       ├── canary.yml                   # Reusable: canary deploy with monitoring
│       ├── rollback.yml                 # Reusable: redeploy known-good image
│       ├── build-image.yml              # Reusable: build + push Docker image to ECR
│       ├── promote-image.yml            # Reusable: retag ECR image across environments
│       ├── run-migrations.yml           # Reusable: Rails db:migrate as k8s pod
│       ├── security-scan.yml            # Reusable: Trivy + Brakeman
│       └── notify.yml                  # Reusable: Slack notifications
├── infra/
│   ├── modules/                         # Terraform modules (vpc, eks, rds, iam, ecr)
│   ├── environments/
│   │   ├── dev/                         # dev env config (env.hcl + module terragrunt.hcl files)
│   │   ├── staging/                     # staging env config
│   │   └── prod/                        # prod env config
│   ├── bootstrap/                       # S3 state backend — run once per environment
│   ├── root.hcl                         # Terragrunt root config (derives env from path)
│   └── backend.tf
├── helm/
│   └── shopstream/                      # Helm chart with per-environment values files
├── shopstream-api/                      # Rails application
├── scripts/
│   ├── canary-check.sh                  # Polls error rates during canary window
│   └── rollback.sh                      # Triggers rollback workflow via GitHub API
└── PLAYBOOK.md                          # Operations runbook — bootstrap, deploy, rollback
```

---

## Environments

| Environment | Branch | EKS Cluster | Trigger |
|---|---|---|---|
| `dev` | `dev` | shopstream-dev | Push to `dev` |
| `staging` | `staging` | shopstream-staging | Merge `dev` → `staging` |
| `prod` | `main` | shopstream-prod | PR merged `staging` → `main` |

Each environment has its own VPC, EKS cluster, and RDS instance. ECR is shared across all environments.

---

## Workflows by Branch

Workflows are scoped to their branch — staging/prod workflows don't exist on `dev` and vice versa. Shared reusable workflows (deploy, canary, rollback, etc.) are present on all branches.

| Branch | Entry-point workflows |
|---|---|
| `dev` | `ci.yml`, `infra-plan.yml`, `infra-apply.yml` |
| `staging` | `staging.yml`, `infra-plan.yml`, `infra-apply.yml` |
| `main` | `prod.yml`, `infra-plan.yml`, `infra-apply.yml` |

---

## Infrastructure

Terraform modules are identical across environments. Only `env.hcl` differs per environment (sizing, CIDR ranges, multi-AZ settings). Terragrunt derives the environment name from the directory path — no hardcoded env strings in module configs.

```
infra/environments/<env>/
├── env.hcl        # sizing vars (instance type, node count, multi_az, etc.)
├── vpc/
├── eks/
├── rds/
├── iam/
└── ecr/           # dev only — ECR is shared, staging/prod reference dev state
```

---

## Getting Started

See [PLAYBOOK.md](PLAYBOOK.md) for step-by-step instructions on:
- Bootstrapping a new environment from scratch
- Required GitHub secrets and variables
- Running infra plan/apply
- Deploying the app
- Rolling back

### Required GitHub Secrets (per environment)

| Secret | Description |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN for GitHub OIDC auth |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL |

### Required GitHub Variables

| Variable | Example |
|---|---|
| `AWS_REGION` | `ca-central-1` |

---

## License

MIT
