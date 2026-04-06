# ShopStream Operations Playbook

Runbook for deploying and operating ShopStream across dev, staging, and prod environments.

---

## Environments

| Environment | Branch  | EKS Cluster        | Purpose                          |
|-------------|---------|-------------------|----------------------------------|
| dev         | `dev`   | shopstream-dev     | Active development, CI runs here |
| staging     | `staging` | shopstream-staging | Pre-prod validation, mirrors prod |
| prod        | `main`  | shopstream-prod    | Live traffic, canary deployments |

---

## Prerequisites

Before running any pipeline, confirm the following are configured in GitHub repository settings.

### GitHub Environments
Go to **Settings → Environments** and create three environments: `dev`, `staging`, `prod`.
- `prod` must have **required reviewers** configured (approval gate for infra apply and app deploys).

### Secrets (per environment)
| Secret | Description |
|--------|-------------|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN GitHub OIDC assumes for deployments |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook for pipeline notifications |

> The ESO IAM role ARN is read directly from Terraform outputs after infra apply — it does not need to be configured as a GitHub secret.

### Repository Variables
| Variable | Example |
|----------|---------|
| `AWS_REGION` | `ca-central-1` |

### AWS Secrets Manager (per environment)
| Secret Path | Contents |
|-------------|----------|
| `shopstream/<env>/rails-master-key` | Rails master key (`config/master.key`) |

---

## Bootstrapping a New Environment

Follow these steps in order when standing up an environment for the first time (e.g. staging has never been deployed).

### Step 1 — Bootstrap Terraform state backend

The S3 state bucket must exist before Terragrunt can run. This is a one-time operation per environment.

```bash
cd infra/bootstrap
terraform init
terraform apply -var="environment=staging"
```

This creates the S3 bucket used by Terragrunt for remote state. Native S3 locking is used — no DynamoDB required.

### Step 2 — Store the Rails master key in Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "shopstream/staging/rails-master-key" \
  --secret-string "$(cat shopstream-api/config/master.key)" \
  --region ca-central-1
```

### Step 3 — Run infra plan

Review what Terraform will create before applying.

Go to **Actions → Infra Staging — Plan → Run workflow** (select `staging` branch).

Or on push to the `staging` branch with changes under `infra/`, the plan runs automatically.

### Step 4 — Run infra apply

Go to **Actions → Infra Staging — Apply → Run workflow**.

This will:
1. Run `terragrunt apply` across all modules (VPC, EKS, RDS, IAM, ECR)
2. Grant the deploy IAM role EKS cluster-admin access
3. Install External Secrets Operator on the cluster

Expect this to take 15–20 minutes on first run (EKS cluster creation).

### Step 5 — Deploy the app

Once infra is up, push to the `staging` branch (or manually trigger **Deploy Staging**) to deploy the app for the first time.

---

## Workflow Reference

### App Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **CI Dev** (`ci.yml`) | Push to `dev` | Test → lint → build image → deploy to dev |
| **Deploy Staging** (`staging.yml`) | Push to `staging` | Promote `dev` ECR tag → staging → deploy |
| **Deploy Prod** (`prod.yml`) | PR merged to `main` | Promote `staging` ECR tag → prod → canary deploy |
| **Canary Deploy** (`canary.yml`) | Called by prod.yml or manual | 10% traffic canary, 10 min monitoring, auto-rollback |
| **Rollback** (`rollback.yml`) | Manual or canary failure | Re-deploys a specified image tag to any environment |

### Infra Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **Infra Dev — Plan** | Push to `dev` (infra/) or manual | Terragrunt plan for dev |
| **Infra Dev — Apply** | Manual only | Terragrunt apply for dev + install controllers |
| **Infra Staging — Plan** | Push to `staging` (infra/) or manual | Terragrunt plan for staging |
| **Infra Staging — Apply** | Manual only | Terragrunt apply for staging + install controllers |
| **Infra Prod — Plan** | PR to `main` (infra/) or manual | Terragrunt plan for prod |
| **Infra Prod — Apply** | Manual only (requires approval) | Terragrunt apply for prod + install controllers |

---

## Image Promotion Flow

Images are built once and promoted — never rebuilt between environments.

```
push to dev
  └─► build image → tagged :<sha> + :dev in ECR

push to staging
  └─► promote :dev → :staging in ECR → deploy to staging cluster

PR merged to main
  └─► promote :staging → :prod in ECR → canary deploy to prod cluster
```

To deploy a specific commit to staging instead of the latest dev image:
1. Go to **Actions → Deploy Staging → Run workflow**
2. Set `image_tag` to the commit SHA

---

## Deploying a Hotfix

When a critical fix needs to bypass the normal dev → staging → prod flow:

1. Create a branch from `main`, make the fix, open a PR to `main`
2. Reviewer approves and merges
3. **Deploy Prod** triggers automatically — promotes staging→prod via canary
4. If the fix also needs to be in dev/staging, cherry-pick the commit to those branches

---

## Rolling Back

### Automatic rollback (prod only)
If the canary monitoring detects elevated errors, `rollback.yml` is triggered automatically.

### Manual rollback (any environment)
1. Go to **Actions → Rollback → Run workflow**
2. Select the environment (`dev`, `staging`, or `prod`)
3. Enter the known-good image tag (commit SHA or `dev`/`staging`)

To find the last successful image tag, check the most recent successful **CI Dev** or **Deploy Staging** run and copy the SHA from the run name.

---

## Updating Infrastructure

For any changes to `infra/`:

1. Make changes on the appropriate branch
2. The plan workflow runs automatically — review the output
3. Trigger the apply workflow manually after review
4. For prod: apply requires approval from a configured reviewer

---

## Secrets Rotation

### Rails master key
```bash
aws secretsmanager put-secret-value \
  --secret-id "shopstream/<env>/rails-master-key" \
  --secret-string "<new-key>" \
  --region ca-central-1
```

After rotating, redeploy the app so pods pick up the new value (ESO syncs on its refresh interval, or delete the k8s secret to force an immediate sync).

### RDS password
RDS managed secrets rotate automatically. The migration workflow reads the current value from Secrets Manager at deploy time — no action needed.

---

## Troubleshooting

### Pods not becoming ready
```bash
kubectl get pods -n shopstream-<env>
kubectl describe pod <pod-name> -n shopstream-<env>
kubectl logs <pod-name> -n shopstream-<env>
```

Common causes:
- **301 on /up probe** — Rails `force_ssl` redirecting HTTP probes. Probes should send `X-Forwarded-Proto: https` header (already configured).
- **CrashLoopBackOff** — Check logs for `DATABASE_URL` or `RAILS_MASTER_KEY` missing. Confirm `shopstream-secrets` k8s secret exists in the namespace.
- **ImagePullBackOff** — ECR login failed or image tag doesn't exist. Check the promote step in the workflow run.

### Migration pod failed
```bash
kubectl get pods -n shopstream-<env> | grep rails-migrate
kubectl logs rails-migrate-<run-id> -n shopstream-<env>
```

### ESO not syncing secrets
```bash
kubectl get externalsecret -n shopstream-<env>
kubectl describe externalsecret shopstream-secrets -n shopstream-<env>
```

Check that the ESO service account has the correct IAM role annotation and that the role has `secretsmanager:GetSecretValue` permissions.

### Terragrunt apply fails on first run
Ensure the S3 state bucket exists (Step 1 of bootstrapping). If the bucket was created manually or in a different region, update `infra/bootstrap/` accordingly.
