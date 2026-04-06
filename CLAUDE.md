# RailsFlow CI — Claude Context

## Project Purpose

A production-grade CI/CD pipeline reference implementation for Ruby on Rails, built entirely on GitHub Actions. This is a **portfolio/showcase project** demonstrating real-world DevOps practices: image promotion, canary deployments, security scanning, multi-environment deploys, and rollback mechanisms.

The fictional app being shipped is **ShopStream** — a Rails e-commerce API split across two repos (`shopstream-api` and `shopstream-infra`).

---

## Tech Stack

| Layer | Tool |
|---|---|
| CI/CD | GitHub Actions (Reusable Workflows, Environments, OIDC) |
| Container Registry | GitHub Container Registry (GHCR) |
| Security | Trivy (container vulns) + Brakeman (Rails static analysis) |
| Deployment | Kubernetes + Helm |
| Notifications | Slack Incoming Webhooks |
| App Runtime | Ruby on Rails |

---

## Repository Structure

```
railsflow-ci/
├── CLAUDE.md
├── README.md
├── .github/
│   └── workflows/
│       ├── ci.yml                  # Main CI pipeline — runs on push to main
│       ├── deploy.yml              # Multi-env deployment (dev → staging → prod)
│       ├── security-scan.yml       # Trivy + Brakeman; blocks pipeline on failure
│       ├── canary.yml              # Canary deploy: 10% traffic, 10min monitoring
│       ├── rollback.yml            # Re-deploys last known-good image tag
│       ├── notify.yml              # Slack notifications for all pipeline events
│       └── _reusable/
│           ├── build-image.yml     # Build + push Docker image to GHCR
│           ├── promote-image.yml   # Promote image tag across environments
│           └── run-migrations.yml  # Rails DB migrations as reusable step
├── helm/
│   └── shopstream/                 # Helm chart — values per environment
├── docker/
│   └── Dockerfile                  # Production Rails image
└── scripts/
    ├── canary-check.sh             # Polls error rates during canary window
    └── rollback.sh                 # Triggers rollback workflow via API
```

---

## Pipeline Architecture

### Flow

```
push to main
  └─► ci.yml (test + lint)
        └─► security-scan.yml (Trivy + Brakeman)
              └─► deploy.yml → dev
                    └─► deploy.yml → staging
                          └─► [manual approval]
                                └─► canary.yml → production (10%)
                                      ├─► canary-check.sh (10 min)
                                      │     ├─► success → full rollout
                                      │     └─► failure → rollback.yml
                                      └─► notify.yml (all stages)
```

### Key Patterns

**Image Promotion** — Docker images are built once in CI and promoted (never rebuilt) across environments. The image tag follows the commit SHA. GHCR is the single source of truth.

**Reusable Workflows** — Common steps (build, promote, migrate) live in `.github/workflows/_reusable/` and are called with `uses:` + `with:` to avoid duplication.

**OIDC Authentication** — No long-lived cloud credentials. Workflows use GitHub's OIDC token to authenticate with cloud providers.

**Canary Deployment** — Production gets 10% of traffic first. `canary-check.sh` polls error rates for 10 minutes. Automatic rollback on elevated errors.

**Manual Approval Gate** — Production deploys require a GitHub Environment approval before proceeding.

---

## GitHub Actions Conventions

- Workflow files use `kebab-case.yml`
- Reusable workflows are prefixed with `_` (e.g., `_reusable/build-image.yml`)
- Every workflow has a top-level comment block explaining its trigger and purpose
- Secrets are referenced via `${{ secrets.SECRET_NAME }}` — never hardcoded
- Environment names match exactly: `dev`, `staging`, `production`
- Image tags follow the pattern: `ghcr.io/org/shopstream-api:<sha>`
- Jobs that must run sequentially use `needs:` explicitly
- All workflows include a `notify.yml` call in their `on: workflow_call` or final job

## Helm Conventions

- One chart (`helm/shopstream/`) with per-environment `values-<env>.yaml` files
- Image tag is always overridden at deploy time: `--set image.tag=<sha>`
- Canary deploy uses a separate Helm release (`shopstream-canary`) targeting a subset of replicas

---

## Secrets & Environment Variables

These secrets are expected to be configured in the GitHub repository/environment settings:

| Secret | Used In |
|---|---|
| `GHCR_TOKEN` | Pushing/pulling images from GHCR |
| `KUBECONFIG` or OIDC role | Kubernetes deployment |
| `SLACK_WEBHOOK_URL` | Slack notifications |
| `BRAKEMAN_OUTPUT_FORMAT` | Security scan reporting |

---

## Important Notes for Claude

- This is a **reference/showcase project** — prioritize clarity and best-practice patterns over brevity. Workflows should be self-documenting.
- When adding new workflows, follow the existing naming conventions and always wire in `notify.yml`.
- The `_reusable/` workflows are called internally — do not trigger them directly via `workflow_dispatch`.
- Canary logic lives in `canary.yml` + `scripts/canary-check.sh` together — changes to one likely need the other.
- Rollback targets the last successful image tag stored as a GitHub Actions output or environment variable — the mechanism should be explicit, not magic.
- Security scans (`security-scan.yml`) must block downstream jobs on failure — never set `continue-on-error: true` there.
