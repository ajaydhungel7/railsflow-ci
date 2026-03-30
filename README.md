# 🚀 RailsFlow CI

> **Ship Rails code like you mean it.**

A production-grade CI/CD pipeline reference implementation for Ruby on Rails, built entirely on GitHub Actions.

---

## Overview

**RailsFlow CI** demonstrates a battle-hardened CI/CD pipeline for a Ruby on Rails e-commerce platform called **ShopStream** — a realistic multi-service application. This project serves as a complete reference for engineering teams who want to ship Rails code safely, consistently, and with confidence.

---

## Pipeline Features

| Feature | Description |
|---|---|
| **Multi-Repo Trigger** | Watches both `shopstream-api` and `shopstream-infra` repos; a push to either triggers the relevant pipeline stages via `repository_dispatch` |
| **Image Promotion Workflow** | Docker images are built once and promoted across environments (dev → staging → production) via GHCR — what you test is what ships |
| **Security Scan Stage** | Trivy for container vulnerability scanning + Brakeman for Rails-specific static analysis; failing scans block the pipeline |
| **Multi-Environment Deployment** | Automated deploys to `dev` and `staging`, with a manual approval gate before `production` |
| **Canary Deployment** | Production releases go to 10% of traffic first, monitored for 10 minutes before full rollout |
| **Slack Notifications** | Rich Slack messages for every meaningful pipeline event — build start, security findings, approvals, canary status, success/failure |
| **Rollback Mechanism** | Automatic re-deploy of last known-good image tag if canary detects elevated error rates |

---

## Tech Stack

- **CI/CD**: GitHub Actions (Reusable Workflows, Environments, OIDC)
- **Container Registry**: GitHub Container Registry (GHCR)
- **Security**: [Trivy](https://github.com/aquasecurity/trivy) + [Brakeman](https://brakemanscanner.org/)
- **Deployment**: Kubernetes + Helm
- **Notifications**: Slack Incoming Webhooks
- **App**: Ruby on Rails (ShopStream e-commerce API)

---

## Repository Structure

```
railsflow-ci/
├── .github/
│   └── workflows/
│       ├── ci.yml                  # Main CI pipeline
│       ├── deploy.yml              # Multi-environment deployment
│       ├── security-scan.yml       # Trivy + Brakeman security stage
│       ├── canary.yml              # Canary deployment & monitoring
│       ├── rollback.yml            # Rollback mechanism
│       ├── notify.yml              # Slack notification workflow
│       └── _reusable/
│           ├── build-image.yml     # Reusable: build & push Docker image
│           ├── promote-image.yml   # Reusable: image promotion across envs
│           └── run-migrations.yml  # Reusable: Rails DB migrations
├── helm/
│   └── shopstream/                 # Helm chart for Kubernetes deployment
├── docker/
│   └── Dockerfile                  # Production Rails Dockerfile
├── scripts/
│   ├── canary-check.sh             # Canary health monitoring script
│   └── rollback.sh                 # Rollback trigger script
└── README.md
```

---

## Getting Started

> 🚧 **Work in progress.** Pipeline workflows and app scaffolding are being added incrementally.

### Prerequisites

- GitHub repository with Actions enabled
- Kubernetes cluster (any cloud provider)
- Slack workspace with Incoming Webhooks configured
- GHCR access (included with your GitHub account)

---

## Environments

| Environment | Trigger | Approval Required |
|---|---|---|
| `dev` | Every push to `main` | No |
| `staging` | Every push to `main` (after dev) | No |
| `production` | Manual or tag push | **Yes** |

---

## Contributing

This is a reference project. Feel free to fork it, adapt the workflows to your own Rails app, and raise issues or PRs with improvements.

---

## License

MIT
