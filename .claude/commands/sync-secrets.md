# sync-secrets

After a `terragrunt apply`, sync the fresh infrastructure outputs to GitHub secrets and Kubernetes.

## What this does

1. Reads `db_endpoint` from the dev RDS terragrunt output
2. Constructs the `DATABASE_URL`
3. Updates the `DATABASE_URL` GitHub secret in `ajaydhungel7/railsflow-ci`
4. Updates the `shopstream-secrets` Kubernetes secret in the dev cluster

## Steps

Ask the user for:
- `DB_PASSWORD` (the RDS master password used during apply — default `P-rasite678`)
- `RAILS_MASTER_KEY` (from `shopstream-api/config/master.key`, or ask if unknown)

Then run the following in order:

### 1. Get RDS endpoint from terragrunt output
```bash
cd /Users/ajaydhungel/Documents/railsflow-ci/infra/environments/dev/rds
terragrunt output --tf-path=$(which terraform) --raw db_endpoint
```

This gives `<host>:5432`. Strip the port to get just the hostname.

### 2. Build DATABASE_URL
```
postgres://shopstream:<DB_PASSWORD>@<rds_host>:5432/shopstream
```

### 3. Update GitHub secret
```bash
gh secret set DATABASE_URL --body "<DATABASE_URL>" --repo ajaydhungel7/railsflow-ci
```

### 4. Update kubeconfig for dev cluster
```bash
aws eks update-kubeconfig --name shopstream-dev --region ca-central-1
```

### 5. Update Kubernetes secret
```bash
kubectl create secret generic shopstream-secrets \
  --from-literal=DATABASE_URL="<DATABASE_URL>" \
  --from-literal=RAILS_MASTER_KEY="<RAILS_MASTER_KEY>" \
  --namespace default \
  --dry-run=client -o yaml | kubectl apply -f -
```

(Using `--dry-run | kubectl apply` so it's idempotent — works on both create and update.)

### 6. Confirm
Print a summary of what was updated and the new RDS endpoint.
