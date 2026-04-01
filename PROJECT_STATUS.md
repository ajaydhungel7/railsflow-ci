# RailsFlow CI — Project Status

## What's Built

### Infrastructure (`infra/`)

5 Terraform modules, state stored in S3 (`shopstream-tfstate-<account_id>`), managed via Terragrunt.

| Module | Resources | Status |
|---|---|---|
| `vpc` | VPC, public/private subnets, route tables | Applied (dev) |
| `eks` | EKS 1.32 cluster, node group, OIDC provider | Applied (dev) |
| `ecr` | ECR repository for shopstream images | Applied (dev) |
| `rds` | PostgreSQL 16.3, subnet group, security group (port 5432 from VPC only) | Config ready |
| `iam` | GitHub Actions OIDC deploy role, ALB controller IRSA role, ECR/EKS policies | Config ready |

**Root config:** `infra/root.hcl` — S3 backend, AWS provider, native S3 locking (`use_lockfile = true`, no DynamoDB)

**Terraform:** >= 1.11 (currently 1.14.8 via tfenv)
**Terragrunt:** 0.99.1

---

### CI/CD (`.github/workflows/`)

#### App Pipeline (`ci.yml`)
Triggered on push to `main` for non-infra files.

```
test (Rails + RuboCop)
  └─► build (Docker → ECR, SHA tag)
        └─► security-scan (Trivy + Brakeman — hard blocks on failure)
              └─► deploy dev
                    └─► deploy staging
                          └─► [manual approval via GitHub Environment]
                                └─► canary (10% prod via shopstream-canary release)
                                      ├─► canary-check.sh polls CloudWatch 10 min
                                      │     ├─► healthy → full rollout
                                      │     └─► unhealthy → rollback.yml
                                      └─► notify.yml (Slack) at every stage
```

#### Infra Pipeline (`infra.yml`)
Triggered on push/PR to `infra/**` only.
- PRs → `terragrunt run-all plan` + comment on PR
- Merge to main → `terragrunt run-all apply --auto-approve`
- Secrets passed as `TF_VAR_*` env vars

#### Reusable Workflows (`_reusable/`)
| Workflow | Purpose |
|---|---|
| `build-image.yml` | Build from `shopstream-api/Dockerfile`, push to ECR |
| `promote-image.yml` | Retag SHA → environment label (no rebuild) |
| `run-migrations.yml` | `kubectl run` one-off Rails migration Job in-cluster |

#### Other Workflows
| Workflow | Purpose |
|---|---|
| `security-scan.yml` | Trivy (container vulns) + Brakeman (Rails static analysis) |
| `deploy.yml` | Promote image → migrate → Helm rollout (dev/staging) |
| `canary.yml` | 10% canary → CloudWatch monitoring → full rollout or rollback |
| `rollback.yml` | Re-deploy known-good image tag via Helm |
| `notify.yml` | Slack notifications, wired into every workflow |

---

### Helm Chart (`helm/shopstream/`)

| Environment | Replicas | ALB Scheme | HPA | HTTPS |
|---|---|---|---|---|
| dev | 1 | internal | off | no |
| staging | 2 | internal | 2–4 pods | no |
| production | 3 | internet-facing | 3–10 pods | ready (uncomment `certificateArn`) |

- Health checks on `/up` (Rails built-in endpoint)
- `DATABASE_URL` + `RAILS_MASTER_KEY` from K8s secret `shopstream-secrets`
- ALB URL printed to CI logs after every deploy
- Canary release uses same chart with `--set replicaCount=1` and separate release name `shopstream-canary`

---

### Scripts (`scripts/`)

**`canary-check.sh`**
- Polls CloudWatch (`AWS/ApplicationELB`) every 30s for 10 min
- Metrics: 5XX error rate (threshold 5%) + p99 latency (threshold 2000ms)
- Works with internal ALBs — queries AWS API, not the ALB directly
- Exits 0 → full rollout | Exits 1 → rollback triggered

**`rollback.sh`**
- Triggers `rollback.yml` via GitHub API (`workflow_dispatch`)
- Auto-resolves last good image tag from Helm history if not provided

---

## GitHub Secrets & Variables Required

Set these in GitHub repository/environment settings before the pipeline can run.

### Repository-level secrets
| Secret | Description |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Output of `iam` Terraform module after applying |
| `DB_PASSWORD` | RDS master password (used as `TF_VAR_db_password` in infra pipeline) |
| `DATABASE_URL` | Full PostgreSQL connection string for Rails migrations |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL |

### Repository-level variables
| Variable | Value |
|---|---|
| `AWS_REGION` | `ca-central-1` |

### Per-environment secrets (set on `dev`, `staging`, `production` GitHub Environments)
| Secret | Description |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Same role ARN (or different per env if needed) |
| `DATABASE_URL` | Environment-specific connection string |

---

## Before Pushing to GitHub

1. **Update GitHub org** in both IAM terragrunt configs:
   - `infra/environments/dev/iam/terragrunt.hcl` → replace `your-org`
   - `infra/environments/prod/iam/terragrunt.hcl` → replace `your-org`

2. **Create GitHub Environments** in repo settings: `dev`, `staging`, `production`
   - Add manual approval reviewers to `production`

3. **Create K8s secret** after first EKS deploy (once per cluster):
   ```bash
   kubectl create secret generic shopstream-secrets \
     --namespace shopstream \
     --from-literal=DATABASE_URL="postgres://..." \
     --from-literal=RAILS_MASTER_KEY="$(cat shopstream-api/config/master.key)"
   ```

4. **Install ALB controller** on the EKS cluster (Helm):
   ```bash
   helm repo add eks https://aws.github.io/eks-charts
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
     -n kube-system \
     --set clusterName=shopstream-dev \
     --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<alb_controller_role_arn>
   ```
   The `alb_controller_role_arn` is an output of the `iam` Terraform module.

---

## HTTPS (Future)

When you acquire a domain:
1. Issue an ACM certificate in `ca-central-1`
2. Validate via DNS (add the CNAME record your registrar/DNS provider)
3. Set `certificateArn` in `helm/shopstream/values-production.yaml`
4. Re-run the deploy workflow — HTTPS with HTTP→443 redirect is enabled automatically

---

## AWS Resources Currently Live (dev)

- EKS cluster: `shopstream-dev` (ca-central-1)
- Cluster endpoint: `https://B98C185D40A5AEDBB294A5F1A75A4AF1.gr7.ca-central-1.eks.amazonaws.com`
- OIDC provider: `oidc.eks.ca-central-1.amazonaws.com/id/B98C185D40A5AEDBB294A5F1A75A4AF1`
- S3 state bucket: `shopstream-tfstate-544234170512`
