#!/usr/bin/env bash
# rollback.sh — triggers the rollback.yml GitHub Actions workflow via the API.
# Called automatically by canary.yml on canary failure, or run manually.
#
# Usage:
#   rollback.sh --env <environment> --repo <owner/repo> --token <github_token> [--image-tag <sha>]
#
# If --image-tag is not provided, the script resolves the last successful
# deployment tag from the Helm release history.

set -euo pipefail

ENVIRONMENT=""
REPO=""
TOKEN=""
IMAGE_TAG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)        ENVIRONMENT="$2"; shift 2 ;;
    --repo)       REPO="$2";        shift 2 ;;
    --token)      TOKEN="$2";       shift 2 ;;
    --image-tag)  IMAGE_TAG="$2";   shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$ENVIRONMENT" ] || [ -z "$REPO" ] || [ -z "$TOKEN" ]; then
  echo "Usage: rollback.sh --env <env> --repo <owner/repo> --token <token> [--image-tag <sha>]" >&2
  exit 1
fi

# If no image tag provided, resolve from Helm history
if [ -z "$IMAGE_TAG" ]; then
  echo "No image tag provided — resolving from Helm release history..."
  NAMESPACE="${NAMESPACE:-shopstream}"

  # Get the previous successful Helm revision's image tag
  IMAGE_TAG=$(helm history shopstream \
    --namespace "$NAMESPACE" \
    --output json \
    2>/dev/null \
    | python3 -c "
import json, sys
history = json.load(sys.stdin)
# Find the last SUPERSEDED (previously deployed) revision
for rev in reversed(history):
    if rev.get('status') == 'superseded':
        desc = rev.get('description', '')
        # Extract image tag from description if present
        # Fall back to revision number as signal
        print(rev.get('app_version', ''))
        break
" || true)

  if [ -z "$IMAGE_TAG" ]; then
    echo "ERROR: Could not resolve previous image tag from Helm history." >&2
    echo "Please provide --image-tag explicitly." >&2
    exit 1
  fi

  echo "Resolved rollback target: $IMAGE_TAG"
fi

echo "Triggering rollback workflow..."
echo "  Repo:        $REPO"
echo "  Environment: $ENVIRONMENT"
echo "  Image tag:   $IMAGE_TAG"

RESPONSE=$(curl -fsSL -w "\n%{http_code}" \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${REPO}/actions/workflows/rollback.yml/dispatches" \
  -d "{
    \"ref\": \"main\",
    \"inputs\": {
      \"environment\": \"${ENVIRONMENT}\",
      \"image_tag\": \"${IMAGE_TAG}\"
    }
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" -eq 204 ]; then
  echo "Rollback workflow triggered successfully."
  echo "Monitor at: https://github.com/${REPO}/actions/workflows/rollback.yml"
else
  echo "ERROR: Failed to trigger rollback workflow (HTTP $HTTP_CODE)" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
